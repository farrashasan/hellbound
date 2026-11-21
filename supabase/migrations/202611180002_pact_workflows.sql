-- Jalankan setelah 202611180001. Tidak mengubah/menghapus tabel yang ada.
BEGIN;
CREATE SCHEMA IF NOT EXISTS hellbound_private;
REVOKE ALL ON SCHEMA hellbound_private FROM PUBLIC, anon, authenticated;

CREATE FUNCTION hellbound_private.event(p uuid, kind text, message text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 INSERT INTO public.pact_activities(pact_id,actor_id,activity_type,description) VALUES(p,auth.uid(),kind,message);
END; $$;
CREATE FUNCTION hellbound_private.breach(p uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.pacts; moment timestamptz := now();
BEGIN
 SELECT * INTO v FROM public.pacts WHERE id=p FOR UPDATE;
 IF v.status NOT IN ('active','under_verification') THEN RETURN; END IF;
 UPDATE public.pacts SET status='breached' WHERE id=p;
 PERFORM hellbound_private.event(p,'breached','Pact breached');
 IF v.consequence_type='app_ban' THEN
 INSERT INTO public.app_bans(pact_id,user_id,app_name,starts_at,ends_at)
 SELECT p,user_id,v.consequence_detail,moment,moment+interval '24 hours' FROM public.pact_members WHERE pact_id=p AND role='responsible'
 ON CONFLICT(pact_id) DO NOTHING;
 END IF;
 INSERT INTO public.notifications(user_id,pact_id,type,message)
 SELECT user_id,p,'consequence','Pact breached: '||v.title FROM public.pact_members WHERE pact_id=p;
END; $$;

CREATE FUNCTION public.hellbound_create_pact(payload jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p uuid; r uuid := (payload->>'responsible_id')::uuid; v uuid := (payload->>'verifier_id')::uuid; w uuid; seen uuid[] := ARRAY[]::uuid[];
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF r IS NULL OR v IS NULL OR r=v THEN RAISE EXCEPTION 'Choose different responsible and verifier'; END IF;
 IF (payload->>'deadline')::timestamptz <= now() THEN RAISE EXCEPTION 'Deadline must be in the future'; END IF;
 INSERT INTO public.pacts(creator_id,title,description,deadline,evidence_type,evidence_requirement,consequence_type,consequence_detail,announcement_audience)
 VALUES(auth.uid(),payload->>'title',payload->>'description',(payload->>'deadline')::timestamptz,payload->>'evidence_type',payload->>'evidence_requirement',payload->>'consequence_type',payload->>'consequence_detail',payload->>'announcement_audience') RETURNING id INTO p;
 INSERT INTO public.pact_members(pact_id,user_id,role) VALUES(p,r,'responsible'),(p,v,'verifier');
 FOR w IN SELECT value::uuid FROM jsonb_array_elements_text(coalesce(payload->'witness_ids','[]'::jsonb)) LOOP
  IF w=r OR w=v OR w=ANY(seen) THEN RAISE EXCEPTION 'Duplicate participant'; END IF;
  seen := array_append(seen,w);
  INSERT INTO public.pact_members(pact_id,user_id,role) VALUES(p,w,'witness');
 END LOOP;
 PERFORM hellbound_private.event(p,'created','Pact created');
 INSERT INTO public.notifications(user_id,pact_id,type,message) SELECT user_id,p,'invitation','You have been invited to '||(payload->>'title') FROM public.pact_members m JOIN public.user_settings s USING(user_id) WHERE pact_id=p AND s.pact_invitations;
 RETURN p;
END; $$;

CREATE FUNCTION public.hellbound_respond(pact uuid, accept boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.pacts;
BEGIN
 IF auth.uid() IS NULL OR accept IS NULL THEN RAISE EXCEPTION 'Invalid response'; END IF;
 SELECT * INTO v FROM public.pacts WHERE id=pact FOR UPDATE;
 IF NOT FOUND OR v.status <> 'awaiting_acceptance' THEN RAISE EXCEPTION 'Pact is no longer awaiting acceptance'; END IF;
 IF v.deadline <= now() THEN RAISE EXCEPTION 'Deadline already passed'; END IF;
 UPDATE public.pact_members SET acceptance_status=CASE WHEN accept THEN 'accepted' ELSE 'declined' END,responded_at=now()
 WHERE pact_id=pact AND user_id=auth.uid() AND acceptance_status='pending';
 IF NOT FOUND THEN RAISE EXCEPTION 'No pending invitation for this account'; END IF;
 PERFORM hellbound_private.event(pact,CASE WHEN accept THEN 'accepted' ELSE 'declined' END,CASE WHEN accept THEN 'Invitation accepted' ELSE 'Invitation declined' END);
 IF NOT accept THEN UPDATE public.pacts SET status='declined' WHERE id=pact;
 ELSIF NOT EXISTS(SELECT 1 FROM public.pact_members WHERE pact_id=pact AND acceptance_status<>'accepted') THEN
 UPDATE public.pacts SET status='active' WHERE id=pact;
 PERFORM hellbound_private.event(pact,'activated','All participants accepted. Pact activated');
 END IF;
END; $$;

CREATE FUNCTION public.hellbound_submit_evidence(pact uuid, body text, photo text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.pacts;
BEGIN
 SELECT * INTO v FROM public.pacts WHERE id=pact FOR UPDATE;
 IF auth.uid() IS NULL OR NOT FOUND OR v.status<>'active' OR v.deadline<=now() OR NOT EXISTS(SELECT 1 FROM public.pact_members WHERE pact_id=pact AND user_id=auth.uid() AND role='responsible') THEN RAISE EXCEPTION 'Evidence submission is not allowed'; END IF;
 IF v.evidence_type='photo' AND photo IS NULL OR v.evidence_type='text' AND coalesce(btrim(body),'')='' THEN RAISE EXCEPTION 'Required evidence missing'; END IF;
 IF photo IS NOT NULL AND NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='pact-evidence' AND name=photo AND split_part(name,'/',1)=auth.uid()::text AND split_part(name,'/',2)=pact::text) THEN RAISE EXCEPTION 'Invalid photo'; END IF;
 INSERT INTO public.evidence_submissions(pact_id,submitted_by,text_content,photo_path) VALUES(pact,auth.uid(),nullif(btrim(body),''),photo);
 UPDATE public.pacts SET status='under_verification' WHERE id=pact;
 PERFORM hellbound_private.event(pact,'evidence_submitted','Evidence submitted');
 INSERT INTO public.notifications(user_id,pact_id,type,message) SELECT user_id,pact,'verification','Evidence ready for review: '||v.title FROM public.pact_members m JOIN public.user_settings s USING(user_id) WHERE pact_id=pact AND role='verifier' AND s.verification_results;
END; $$;

CREATE FUNCTION public.hellbound_review(pact uuid, approve boolean, notes text DEFAULT '') RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v public.pacts; eid uuid;
BEGIN
 SELECT * INTO v FROM public.pacts WHERE id=pact FOR UPDATE;
 IF auth.uid() IS NULL OR approve IS NULL OR NOT FOUND OR v.status<>'under_verification' OR NOT EXISTS(SELECT 1 FROM public.pact_members WHERE pact_id=pact AND user_id=auth.uid() AND role='verifier') THEN RAISE EXCEPTION 'Only the verifier can review pending evidence'; END IF;
 SELECT id INTO eid FROM public.evidence_submissions WHERE pact_id=pact AND review_status='pending' ORDER BY submitted_at DESC LIMIT 1;
 IF eid IS NULL THEN RAISE EXCEPTION 'No pending evidence'; END IF;
 UPDATE public.evidence_submissions SET review_status=CASE WHEN approve THEN 'approved' ELSE 'rejected' END,reviewed_by=auth.uid(),reviewed_at=now(),review_notes=notes WHERE id=eid;
 PERFORM hellbound_private.event(pact,CASE WHEN approve THEN 'evidence_approved' ELSE 'evidence_rejected' END,CASE WHEN approve THEN 'Evidence approved' ELSE 'Evidence rejected' END);
 IF approve THEN
 UPDATE public.pacts SET status='completed' WHERE id=pact;
 PERFORM hellbound_private.event(pact,'completed','Pact completed');
 ELSE PERFORM hellbound_private.breach(pact); END IF;
 INSERT INTO public.notifications(user_id,pact_id,type,message) SELECT user_id,pact,'verification','Evidence '||CASE WHEN approve THEN 'approved: ' ELSE 'rejected: ' END||v.title FROM public.pact_members m JOIN public.user_settings s USING(user_id) WHERE pact_id=pact AND s.verification_results;
END; $$;

CREATE UNIQUE INDEX notifications_one_deadline_reminder ON public.notifications(user_id,pact_id) WHERE type='deadline';

-- Dipanggil saat refresh. Bukti yang sudah diserahkan tepat waktu tetap menunggu verifikasi.
CREATE FUNCTION public.hellbound_expire_due() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 FOR p IN SELECT id FROM public.pacts WHERE status='active' AND deadline<=now() AND public.hellbound_can_read_pact(id) ORDER BY id FOR UPDATE LOOP
 PERFORM hellbound_private.breach(p);
 END LOOP;
 INSERT INTO public.notifications(user_id,pact_id,type,message)
 SELECT auth.uid(),p.id,'deadline','Deadline within 24 hours: '||p.title
 FROM public.pacts p JOIN public.pact_members m ON m.pact_id=p.id
 JOIN public.user_settings s ON s.user_id=m.user_id
 WHERE m.user_id=auth.uid() AND s.deadline_reminders AND p.status='active'
 AND p.deadline>now() AND p.deadline<=now()+interval '24 hours'
 ON CONFLICT(user_id,pact_id) WHERE type='deadline' DO NOTHING;
END; $$;

CREATE FUNCTION public.hellbound_can_upload(path text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT EXISTS(SELECT 1 FROM public.pacts p JOIN public.pact_members m ON m.pact_id=p.id
 WHERE split_part(path,'/',1)=auth.uid()::text AND split_part(path,'/',2)=p.id::text
 AND m.user_id=auth.uid() AND m.role='responsible' AND p.status='active' AND p.deadline>now());
$$;
CREATE FUNCTION public.hellbound_can_read_photo(path text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT split_part(path,'/',1)=auth.uid()::text OR EXISTS(SELECT 1 FROM public.evidence_submissions e WHERE e.photo_path=path AND public.hellbound_can_read_pact(e.pact_id));
$$;
CREATE POLICY evidence_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='pact-evidence' AND public.hellbound_can_upload(name));
CREATE POLICY evidence_download ON storage.objects FOR SELECT TO authenticated USING(bucket_id='pact-evidence' AND public.hellbound_can_read_photo(name));
CREATE POLICY evidence_remove_unused ON storage.objects FOR DELETE TO authenticated USING(bucket_id='pact-evidence' AND split_part(name,'/',1)=auth.uid()::text AND NOT EXISTS(SELECT 1 FROM public.evidence_submissions e WHERE e.photo_path=name));
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA hellbound_private FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.hellbound_create_pact(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_create_pact(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.hellbound_respond(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_respond(uuid,boolean) TO authenticated;
REVOKE ALL ON FUNCTION public.hellbound_submit_evidence(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_submit_evidence(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.hellbound_review(uuid,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_review(uuid,boolean,text) TO authenticated;
REVOKE ALL ON FUNCTION public.hellbound_expire_due() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_expire_due() TO authenticated;
REVOKE ALL ON FUNCTION public.hellbound_can_upload(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_can_upload(text) TO authenticated;
REVOKE ALL ON FUNCTION public.hellbound_can_read_photo(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_can_read_photo(text) TO authenticated;
COMMIT;
