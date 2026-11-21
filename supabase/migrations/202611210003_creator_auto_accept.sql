-- Apply after migrations 001 and 002. Does not delete pacts or participant responses.
BEGIN;
CREATE OR REPLACE FUNCTION public.hellbound_create_pact(payload jsonb) RETURNS uuid
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
 UPDATE public.pact_members SET acceptance_status='accepted', responded_at=now()
 WHERE pact_id=p AND user_id=auth.uid();
 IF FOUND THEN
   PERFORM hellbound_private.event(p,'accepted','Creator accepted when creating the pact');
 END IF;
 INSERT INTO public.notifications(user_id,pact_id,type,message) SELECT user_id,p,'invitation','You have been invited to '||(payload->>'title') FROM public.pact_members m JOIN public.user_settings s USING(user_id) WHERE pact_id=p AND acceptance_status='pending' AND s.pact_invitations;
 RETURN p;
END; $$;


-- Existing pending pacts: creation counts as the creator's consent.
-- Preserve every other participant's response, including declines.
DO $$
DECLARE v record;
BEGIN
 FOR v IN SELECT id,creator_id,deadline FROM public.pacts
          WHERE status='awaiting_acceptance' ORDER BY id FOR UPDATE LOOP
   UPDATE public.pact_members SET acceptance_status='accepted',responded_at=now()
   WHERE pact_id=v.id AND user_id=v.creator_id AND acceptance_status='pending';
   IF FOUND THEN
     INSERT INTO public.pact_activities(pact_id,actor_id,activity_type,description)
     VALUES(v.id,v.creator_id,'accepted','Creator accepted when creating the pact');
     UPDATE public.notifications SET read_at=coalesce(read_at,now())
     WHERE pact_id=v.id AND user_id=v.creator_id AND type='invitation';
     IF v.deadline>now() AND NOT EXISTS (
       SELECT 1 FROM public.pact_members WHERE pact_id=v.id AND acceptance_status<>'accepted'
     ) THEN
       UPDATE public.pacts SET status='active' WHERE id=v.id;
       INSERT INTO public.pact_activities(pact_id,actor_id,activity_type,description)
       VALUES(v.id,NULL,'activated','All participants accepted. Pact activated');
     END IF;
   END IF;
 END LOOP;
END; $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
