-- Hellbound: skema awal untuk project Supabase baru. Jalankan sekali.
-- Bukan migrasi rename untuk database yang sudah memiliki profiles.
-- user selalu dikutip karena USER adalah keyword PostgreSQL.
-- Auth mengelola email/password; public.user hanya profil aplikasi.
-- Waktu disimpan sebagai timestamptz. UI menampilkan zona waktu perangkat.
BEGIN;

CREATE TABLE public.user (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text NOT NULL CHECK (char_length(btrim(username)) BETWEEN 1 AND 60),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_settings (
  user_id uuid PRIMARY KEY REFERENCES public.user(id) ON DELETE CASCADE,
  deadline_reminders boolean NOT NULL DEFAULT true,
  pact_invitations boolean NOT NULL DEFAULT true,
  verification_results boolean NOT NULL DEFAULT true
);

CREATE TABLE public.pacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id uuid NOT NULL REFERENCES public.user(id),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 200),
  description text NOT NULL CHECK (btrim(description) <> ''),
  deadline timestamptz NOT NULL,
  evidence_type text NOT NULL CHECK (evidence_type IN ('photo','text','photo_or_text')),
  evidence_requirement text NOT NULL CHECK (btrim(evidence_requirement) <> ''),
  consequence_type text NOT NULL CHECK (consequence_type IN ('funny_forfeit','private_shame_card','app_ban')),
  -- Tugas forfeit, teks pengumuman, atau nama aplikasi yang dipilih.
  consequence_detail text NOT NULL CHECK (btrim(consequence_detail) <> ''),
  announcement_audience text CHECK (announcement_audience IN ('pact_members','community')),
  status text NOT NULL DEFAULT 'awaiting_acceptance'
    CHECK (status IN ('awaiting_acceptance','active','under_verification','completed','breached','declined')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((consequence_type = 'private_shame_card' AND announcement_audience IS NOT NULL)
      OR (consequence_type <> 'private_shame_card' AND announcement_audience IS NULL)),
  CHECK (deadline > created_at)
);

CREATE TABLE public.pact_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user(id),
  role text NOT NULL CHECK (role IN ('responsible','verifier','witness')),
  acceptance_status text NOT NULL DEFAULT 'pending' CHECK (acceptance_status IN ('pending','accepted','declined')),
  responded_at timestamptz,
  UNIQUE (pact_id,user_id),
  CHECK ((acceptance_status = 'pending' AND responded_at IS NULL)
      OR (acceptance_status <> 'pending' AND responded_at IS NOT NULL))
);
-- Maksimal satu responsible dan satu verifier; minimal keduanya perlu divalidasi
-- oleh transaksi pembuatan pakta (RPC/backend), bersama daftar saksi.
CREATE UNIQUE INDEX pact_one_responsible ON public.pact_members(pact_id) WHERE role = 'responsible';
CREATE UNIQUE INDEX pact_one_verifier ON public.pact_members(pact_id) WHERE role = 'verifier';
CREATE INDEX pact_members_user_idx ON public.pact_members(user_id,pact_id);
CREATE INDEX pacts_creator_idx ON public.pacts(creator_id);
CREATE INDEX pacts_deadline_idx ON public.pacts(deadline) WHERE status = 'active';

CREATE TABLE public.evidence_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  submitted_by uuid NOT NULL REFERENCES public.user(id),
  text_content text,
  -- Object path di bucket privat pact-evidence, bukan URL publik/URL sementara.
  photo_path text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  review_status text NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','approved','rejected')),
  reviewed_by uuid REFERENCES public.user(id),
  review_notes text,
  reviewed_at timestamptz,
  CHECK (coalesce(btrim(text_content),'') <> '' OR coalesce(btrim(photo_path),'') <> ''),
  CHECK ((review_status = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL)
      OR (review_status <> 'pending' AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)),
  CHECK (reviewed_at IS NULL OR reviewed_at >= submitted_at),
  CHECK (reviewed_by IS NULL OR reviewed_by <> submitted_by)
);
CREATE INDEX evidence_pact_idx ON public.evidence_submissions(pact_id,submitted_at DESC);
CREATE INDEX evidence_submitter_idx ON public.evidence_submissions(submitted_by);
CREATE INDEX evidence_reviewer_idx ON public.evidence_submissions(reviewed_by);

CREATE TABLE public.pact_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id uuid NOT NULL REFERENCES public.pacts(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES public.user(id), -- NULL untuk aktivitas sistem.
  activity_type text NOT NULL CHECK (activity_type IN ('created','invited','accepted','declined','activated','evidence_submitted','evidence_approved','evidence_rejected','completed','breached','ban_started','ban_ended')),
  description text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX activities_pact_idx ON public.pact_activities(pact_id,created_at);
CREATE INDEX activities_actor_idx ON public.pact_activities(actor_id);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user(id) ON DELETE CASCADE,
  pact_id uuid REFERENCES public.pacts(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('invitation','deadline','verification','consequence')),
  message text NOT NULL,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_idx ON public.notifications(user_id,created_at DESC);
CREATE INDEX notifications_pact_idx ON public.notifications(pact_id);

CREATE TABLE public.app_bans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pact_id uuid NOT NULL UNIQUE REFERENCES public.pacts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user(id),
  app_name text NOT NULL CHECK (btrim(app_name) <> ''),
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL,
  CHECK (ends_at = starts_at + interval '24 hours')
);
CREATE INDEX bans_user_idx ON public.app_bans(user_id,ends_at);

-- Profil dan preferensi otomatis untuk akun Auth baru.
CREATE FUNCTION public.hellbound_create_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.user(id,username)
    VALUES (new.id, left(coalesce(nullif(btrim(new.raw_user_meta_data->>'username'),''),'Mortal'),60));
  INSERT INTO public.user_settings(user_id) VALUES (new.id);
  RETURN new;
END;
$$;
REVOKE ALL ON FUNCTION public.hellbound_create_user() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER hellbound_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.hellbound_create_user();
-- Mendukung akun Auth yang sudah ada sebelum skema ini dipasang.
INSERT INTO public.user(id,username)
SELECT id,left(coalesce(nullif(btrim(raw_user_meta_data->>'username'),''),'Mortal'),60) FROM auth.users;
INSERT INTO public.user_settings(user_id) SELECT id FROM public.user;

-- Helper menghindari rekursi policy pact_members <-> pacts.
CREATE FUNCTION public.hellbound_can_read_pact(target uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.pacts p WHERE p.id = target AND p.creator_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.pact_members m WHERE m.pact_id = target AND m.user_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION public.hellbound_can_read_pact(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_can_read_pact(uuid) TO authenticated;

-- Tidak membuka write transaksi pakta dari client sebelum RPC alur bisnis dibuat.
-- service_role hanya boleh dipakai backend tepercaya, tidak dalam Flutter.
ALTER TABLE public.user ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user FROM anon, authenticated;
GRANT SELECT ON public.user TO authenticated;
GRANT ALL ON public.user TO service_role;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_settings FROM anon, authenticated;
GRANT SELECT ON public.user_settings TO authenticated;
GRANT ALL ON public.user_settings TO service_role;
ALTER TABLE public.pacts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pacts FROM anon, authenticated;
GRANT SELECT ON public.pacts TO authenticated;
GRANT ALL ON public.pacts TO service_role;
ALTER TABLE public.pact_members ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pact_members FROM anon, authenticated;
GRANT SELECT ON public.pact_members TO authenticated;
GRANT ALL ON public.pact_members TO service_role;
ALTER TABLE public.evidence_submissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.evidence_submissions FROM anon, authenticated;
GRANT SELECT ON public.evidence_submissions TO authenticated;
GRANT ALL ON public.evidence_submissions TO service_role;
ALTER TABLE public.pact_activities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pact_activities FROM anon, authenticated;
GRANT SELECT ON public.pact_activities TO authenticated;
GRANT ALL ON public.pact_activities TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications FROM anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.app_bans ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_bans FROM anon, authenticated;
GRANT SELECT ON public.app_bans TO authenticated;
GRANT ALL ON public.app_bans TO service_role;

CREATE POLICY users_read ON public.user FOR SELECT TO authenticated USING (true);
GRANT UPDATE (username) ON public.user TO authenticated;
CREATE POLICY users_edit_self ON public.user FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid())) WITH CHECK (id = (SELECT auth.uid()));
CREATE POLICY settings_read_self ON public.user_settings FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));
GRANT UPDATE (deadline_reminders,pact_invitations,verification_results) ON public.user_settings TO authenticated;
CREATE POLICY settings_edit_self ON public.user_settings FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY pacts_read ON public.pacts FOR SELECT TO authenticated USING (public.hellbound_can_read_pact(id));
CREATE POLICY members_read ON public.pact_members FOR SELECT TO authenticated USING (public.hellbound_can_read_pact(pact_id));
CREATE POLICY evidence_read ON public.evidence_submissions FOR SELECT TO authenticated USING (public.hellbound_can_read_pact(pact_id));
CREATE POLICY activities_read ON public.pact_activities FOR SELECT TO authenticated USING (public.hellbound_can_read_pact(pact_id));
CREATE POLICY notifications_read_self ON public.notifications FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));
GRANT UPDATE (read_at) ON public.notifications TO authenticated;
CREATE POLICY notifications_mark_read ON public.notifications FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY bans_read ON public.app_bans FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()) OR public.hellbound_can_read_pact(pact_id));

-- Feed hanya mengekspos informasi pengumuman; bukan bukti atau isi pakta privat.
CREATE FUNCTION public.hellbound_wall_of_shame()
RETURNS TABLE(pact_id uuid, title text, username text, announcement text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT p.id,p.title,u.username,p.consequence_detail
 FROM public.pacts p
 JOIN public.pact_members m ON m.pact_id = p.id AND m.role = 'responsible'
 JOIN public.user u ON u.id = m.user_id
 WHERE auth.uid() IS NOT NULL AND p.status = 'breached'
   AND p.consequence_type = 'private_shame_card' AND p.announcement_audience = 'community'
   AND NOT EXISTS (SELECT 1 FROM public.pact_members a WHERE a.pact_id = p.id AND a.acceptance_status <> 'accepted');
$$;
REVOKE ALL ON FUNCTION public.hellbound_wall_of_shame() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hellbound_wall_of_shame() TO authenticated;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES ('pact-evidence','pact-evidence',false,10485760,ARRAY['image/jpeg','image/png','image/webp']);
-- Bucket sengaja tanpa policy client: upload/download diaktifkan bersama RPC bukti.
COMMIT;
