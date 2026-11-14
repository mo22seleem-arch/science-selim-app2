-- =====================================================================================
--  العلوم مع محمد سليم  —  Supabase FULL SETUP (from scratch)
--  Run ONCE in: Supabase Dashboard > SQL Editor > New query > paste all > Run
--  Covers: schema + courses by grade + codes + lectures/quizzes + audit + integrity + RLS + storage + realtime
--  Re-runnable: types/tables/functions/policies are guarded, so running twice won't fail.
-- =====================================================================================

-- (OPTIONAL) full reset — uncomment ONLY if you want to wipe everything and start over:
-- drop table if exists integrity_nonces, code_attempts, audit_log, enrollments, activation_codes, quiz_attempts,
--   question_keys, questions, quizzes, lectures, units, courses, device_sessions, profiles cascade;
-- drop type if exists user_role, access_type, duration_type, code_status cascade;

-- ============================ 1) TYPES ============================
do $$ begin create type user_role     as enum ('student','sub_admin','super_admin'); exception when duplicate_object then null; end $$;
do $$ begin create type access_type   as enum ('free','paid');                       exception when duplicate_object then null; end $$;
do $$ begin create type duration_type as enum ('permanent','timed');                 exception when duplicate_object then null; end $$;
do $$ begin create type code_status   as enum ('unused','used','revoked');           exception when duplicate_object then null; end $$;

-- ============================ 2) TABLES ============================
create table if not exists profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  phone text not null unique check (phone ~ '^01[0125][0-9]{8}$'),     -- Egyptian mobile: 010/011/012/015 + 8 digits
  role user_role not null default 'student',
  permissions text[] not null default '{}',                              -- 'content','codes','sessions','settings'
  active_device_id text,                                                 -- single-device lock
  is_banned boolean not null default false,
  integrity_ok_until timestamptz,                                        -- Play Integrity result (12h)
  created_at timestamptz not null default now()
);
create unique index if not exists one_super_admin on profiles(role) where role = 'super_admin';   -- exactly one owner

create table if not exists device_sessions (
  user_id uuid primary key references profiles on delete cascade,
  device_id text not null, device_name text,
  last_seen timestamptz not null default now()
);

-- Three FIXED stages: 1 = الأول الإعدادي | 2 = الثاني الإعدادي | 3 = الثالث الإعدادي   (NO seed data: all start empty)
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  grade smallint not null check (grade in (1,2,3)),
  title text not null, description text, thumbnail_url text,
  access access_type not null default 'paid',                            -- 'free' = open to all | 'paid' = needs activation code
  sort_order int default 0,
  created_at timestamptz default now()
);
create table if not exists units (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses on delete cascade,
  title text not null, access access_type not null default 'paid', sort_order int default 0
);
create table if not exists lectures (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references units on delete cascade,
  title text not null, sort_order int default 0,
  video_provider text check (video_provider in ('bunny','hls')),
  video_ref text,                                                        -- Bunny video GUID / HLS url
  pdf_path text                                                          -- path inside private bucket 'lecture-pdfs'
);
create table if not exists quizzes (
  id uuid primary key default gen_random_uuid(),
  lecture_id uuid not null unique references lectures on delete cascade,
  title text, pass_percent int default 50
);
create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes on delete cascade,
  body text not null, options jsonb not null, sort_order int default 0
);
create table if not exists question_keys (                               -- correct answers: never readable by students
  question_id uuid primary key references questions on delete cascade,
  correct_index int not null
);
create table if not exists quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  quiz_id uuid not null references quizzes on delete cascade,
  score_percent int not null, created_at timestamptz default now()
);

create table if not exists activation_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  course_id uuid references courses on delete cascade,
  unit_id uuid references units on delete cascade,
  check ((course_id is null) <> (unit_id is null)),                      -- tied to exactly ONE target
  duration duration_type not null,
  duration_days int check (duration = 'permanent' or duration_days > 0),
  redeem_before timestamptz,                                             -- code expiry (optional)
  status code_status not null default 'unused',
  batch_id uuid, created_by uuid references profiles, created_at timestamptz default now(),
  used_by uuid references profiles, used_at timestamptz, used_device_id text
);
create table if not exists enrollments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  course_id uuid references courses on delete cascade,
  unit_id uuid references units on delete cascade,
  code_id uuid references activation_codes, device_id text,
  starts_at timestamptz default now(), ends_at timestamptz               -- null = permanent
);

create table if not exists audit_log (
  id bigserial primary key, actor uuid, actor_name text,
  action text not null, target text, meta jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table if not exists code_attempts (
  id bigserial primary key,
  user_id uuid not null references profiles on delete cascade,
  code_tried text, success boolean not null, error text,
  created_at timestamptz not null default now()
);
create table if not exists integrity_nonces (
  user_id uuid primary key references profiles on delete cascade,
  nonce text not null, created_at timestamptz not null default now()
);

-- ============================ 3) INDEXES ============================
create index if not exists idx_courses_grade   on courses (grade, sort_order);
create index if not exists idx_units_course    on units (course_id, sort_order);
create index if not exists idx_enroll_user     on enrollments (user_id);
create index if not exists idx_codes_batch     on activation_codes (batch_id, created_at desc);
create index if not exists idx_audit_created   on audit_log (created_at desc);
create index if not exists idx_attempts_user   on code_attempts (user_id, created_at desc);

-- ============================ 4) HELPER FUNCTIONS ============================
create or replace function is_super() returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and role = 'super_admin') $$;

create or replace function has_perm(p text) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and not is_banned
                 and (role = 'super_admin' or (role = 'sub_admin' and p = any(permissions)))) $$;

create or replace function has_access(p_course uuid, p_unit uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select has_perm('content')
      or exists(select 1 from courses c where c.id = p_course and c.access = 'free')
      or exists(select 1 from units u   where u.id = p_unit   and u.access = 'free')
      or exists(select 1 from enrollments e where e.user_id = auth.uid()
                and (e.course_id = p_course or e.unit_id = p_unit) and (e.ends_at is null or e.ends_at > now()))
$$;

create or replace function lecture_access(p_lecture uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from lectures l join units u on u.id = l.unit_id
                where l.id = p_lecture and has_access(u.course_id, u.id)) $$;

create or replace function log_audit(p_action text, p_target text, p_meta jsonb default '{}'::jsonb) returns void
language sql security definer set search_path = public as $$
  insert into audit_log(actor, actor_name, action, target, meta)
  values (auth.uid(), (select full_name from profiles where id = auth.uid()), p_action, p_target, p_meta) $$;
revoke all on function log_audit(text, text, jsonb) from public, anon, authenticated;   -- internal only

-- ============================ 5) TRIGGERS ============================
-- New signup: validates phone + triple name; the owner phone becomes the one and only super admin.
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare v_name  text := trim(regexp_replace(coalesce(new.raw_user_meta_data->>'full_name',''), '\s+', ' ', 'g'));
        v_phone text := coalesce(new.raw_user_meta_data->>'phone', '');
        v_role  user_role := 'student';
begin
  if v_phone !~ '^01[0125][0-9]{8}$' then raise exception 'invalid_phone'; end if;
  if v_phone = '01091277447' then
     v_role := 'super_admin'; v_name := 'MOHAMED SELIM';
  elsif not exists(select 1 from profiles where role = 'super_admin') then
     raise exception 'owner_not_registered';            -- the owner must register FIRST
  elsif coalesce(array_length(string_to_array(v_name, ' '), 1), 0) < 3 then
     raise exception 'triple_name_required';
  end if;
  insert into profiles(id, full_name, phone, role) values (new.id, v_name, v_phone, v_role);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- Audit every content change
create or replace function audit_content() returns trigger language plpgsql security definer set search_path = public as $$
declare v jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  perform log_audit(tg_table_name || '.' || lower(tg_op), v->>'id', jsonb_build_object('title', v->>'title'));
  return null;
end $$;
drop trigger if exists audit_courses  on courses;  create trigger audit_courses  after insert or update or delete on courses  for each row execute function audit_content();
drop trigger if exists audit_units    on units;    create trigger audit_units    after insert or update or delete on units    for each row execute function audit_content();
drop trigger if exists audit_lectures on lectures; create trigger audit_lectures after insert or update or delete on lectures for each row execute function audit_content();

-- ============================ 6) RPC FUNCTIONS ============================
-- Single-device lock: claims this device, kills every other session, logs device switches (account-sharing signal)
create or replace function register_device(p_device_id text, p_device_name text default null) returns void
language plpgsql security definer set search_path = public, auth as $$
declare v_sid uuid := nullif(auth.jwt()->>'session_id', '')::uuid; v_old text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select active_device_id into v_old from profiles where id = auth.uid();
  if (select is_banned from profiles where id = auth.uid()) then raise exception 'banned'; end if;
  update profiles set active_device_id = p_device_id where id = auth.uid();          -- Realtime tells the old phone
  insert into device_sessions(user_id, device_id, device_name) values (auth.uid(), p_device_id, p_device_name)
    on conflict (user_id) do update set device_id = excluded.device_id, device_name = excluded.device_name, last_seen = now();
  begin delete from auth.sessions where user_id = auth.uid() and id <> v_sid;
  exception when others then null; end;               -- never block login; Realtime + polling still log the old phone out
  if v_old is not null and v_old <> p_device_id then
    perform log_audit('device.switch', auth.uid()::text, jsonb_build_object('from', v_old, 'to', p_device_id, 'name', p_device_name));
  end if;
end $$;

create or replace function admin_reset_device(p_user uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  update profiles set active_device_id = null where id = p_user;
  delete from device_sessions where user_id = p_user;
  begin delete from auth.sessions where user_id = p_user; exception when others then null; end;
  perform log_audit('student.device_reset', p_user::text);
end $$;

create or replace function admin_set_role(p_user uuid, p_role user_role, p_perms text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  if p_role = 'super_admin' then raise exception 'cannot_create_super_admin'; end if;
  if (select role from profiles where id = p_user) = 'super_admin' then raise exception 'owner_protected'; end if;
  update profiles set role = p_role, permissions = coalesce(p_perms, '{}') where id = p_user;
  perform log_audit('staff.set_role', p_user::text, jsonb_build_object('role', p_role, 'perms', p_perms));
end $$;

create or replace function admin_set_ban(p_user uuid, p_ban boolean) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  if (select role from profiles where id = p_user) = 'super_admin' then raise exception 'owner_protected'; end if;
  update profiles set is_banned = p_ban where id = p_user;
  if p_ban then begin delete from auth.sessions where user_id = p_user; exception when others then null; end; end if;
  perform log_audit(case when p_ban then 'student.ban' else 'student.unban' end, p_user::text);
end $$;

create or replace function admin_generate_codes(p_count int, p_course uuid, p_unit uuid, p_duration duration_type,
  p_days int, p_redeem_before timestamptz) returns setof text
language plpgsql security definer set search_path = public as $$
declare v_batch uuid := gen_random_uuid(); v_code text;
begin
  if not has_perm('codes') then raise exception 'forbidden'; end if;
  if p_count not between 1 and 500 then raise exception 'bad_count'; end if;
  for i in 1..p_count loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 16));      -- 16 hex chars from a CSPRNG uuid
    insert into activation_codes(code, course_id, unit_id, duration, duration_days, redeem_before, batch_id, created_by)
      values (v_code, p_course, p_unit, p_duration, p_days, p_redeem_before, v_batch, auth.uid());
    return next v_code;
  end loop;
  perform log_audit('codes.generate', v_batch::text,
    jsonb_build_object('count', p_count, 'course', p_course, 'unit', p_unit, 'duration', p_duration, 'days', p_days));
end $$;

create or replace function admin_revoke_code(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not has_perm('codes') then raise exception 'forbidden'; end if;
  update activation_codes set status = 'revoked' where id = p_id and status = 'unused';
  perform log_audit('codes.revoke', p_id::text);
end $$;

-- Redeem: exists? unused? right target? not expired?  + 5 wrong tries / 15 min lockout. Returns 'ok' or an error code.
create or replace function redeem_code(p_code text, p_course uuid, p_unit uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c activation_codes; v_dev text; v_fail int; v_err text;
begin
  if auth.uid() is null then return 'not_authenticated'; end if;
  select active_device_id into v_dev from profiles where id = auth.uid() and not is_banned;
  if v_dev is null then return 'no_active_device'; end if;
  select count(*) into v_fail from code_attempts
    where user_id = auth.uid() and not success and created_at > now() - interval '15 minutes';
  if v_fail >= 5 then return 'too_many_attempts'; end if;

  select * into c from activation_codes where code = upper(trim(p_code)) for update;
  if not found then v_err := 'code_invalid';
  elsif c.status <> 'unused' then v_err := 'code_used';
  elsif c.course_id is distinct from p_course or c.unit_id is distinct from p_unit then v_err := 'code_wrong_target';
  elsif c.redeem_before is not null and c.redeem_before < now() then v_err := 'code_expired';
  end if;
  if v_err is not null then
    insert into code_attempts(user_id, code_tried, success, error) values (auth.uid(), left(coalesce(p_code, ''), 40), false, v_err);
    return v_err;
  end if;

  insert into enrollments(user_id, course_id, unit_id, code_id, device_id, ends_at)
    values (auth.uid(), c.course_id, c.unit_id, c.id, v_dev,
            case when c.duration = 'timed' then now() + make_interval(days => c.duration_days) end);
  update activation_codes set status = 'used', used_by = auth.uid(), used_at = now(), used_device_id = v_dev where id = c.id;
  insert into code_attempts(user_id, code_tried, success) values (auth.uid(), c.code, true);
  return 'ok';
end $$;

-- Server-side auto-grading (answers are revealed only after submitting)
create or replace function submit_quiz(p_quiz uuid, p_answers jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_pass int; v_total int; v_ok int; v_pct int; v_review jsonb;
begin
  if not exists(select 1 from quizzes z join lectures l on l.id = z.lecture_id join units u on u.id = l.unit_id
                where z.id = p_quiz and has_access(u.course_id, u.id)) then raise exception 'forbidden'; end if;
  select pass_percent into v_pass from quizzes where id = p_quiz;
  with r as (
    select q.id, q.sort_order, k.correct_index,
           case when (p_answers->>(q.id::text)) ~ '^[0-9]+$' then (p_answers->>(q.id::text))::int end as chosen
    from questions q join question_keys k on k.question_id = q.id where q.quiz_id = p_quiz)
  select count(*), count(*) filter (where chosen = correct_index),
         coalesce(jsonb_agg(jsonb_build_object('id', id, 'correct_index', correct_index, 'chosen', chosen) order by sort_order), '[]'::jsonb)
    into v_total, v_ok, v_review from r;
  if v_total = 0 then raise exception 'empty_quiz'; end if;
  v_pct := round(100.0 * v_ok / v_total);
  insert into quiz_attempts(user_id, quiz_id, score_percent) values (auth.uid(), p_quiz, v_pct);
  return jsonb_build_object('score', v_pct, 'passed', v_pct >= v_pass, 'correct', v_ok, 'total', v_total, 'review', v_review);
end $$;

-- ============================ 7) ROW LEVEL SECURITY ============================
alter table profiles         enable row level security;
alter table device_sessions  enable row level security;
alter table courses          enable row level security;
alter table units            enable row level security;
alter table lectures         enable row level security;
alter table quizzes          enable row level security;
alter table questions        enable row level security;
alter table question_keys    enable row level security;
alter table quiz_attempts    enable row level security;
alter table activation_codes enable row level security;
alter table enrollments      enable row level security;
alter table audit_log        enable row level security;
alter table code_attempts    enable row level security;
alter table integrity_nonces enable row level security;      -- no policies on purpose: service role only

-- profiles can only change through the RPCs above
revoke insert, update, delete on profiles from anon, authenticated;

drop policy if exists p_self      on profiles;         create policy p_self      on profiles        for select using (id = auth.uid() or has_perm('sessions'));
drop policy if exists ds_read     on device_sessions;  create policy ds_read     on device_sessions for select using (has_perm('sessions'));

-- catalogue is visible to every signed-in user (paid content stays locked by lectures/quizzes policies)
drop policy if exists c_read      on courses;          create policy c_read      on courses         for select using (auth.uid() is not null);
drop policy if exists u_read      on units;            create policy u_read      on units           for select using (auth.uid() is not null);
-- owner OR sub-admins granted 'content' can add/edit/delete courses & units
drop policy if exists c_write     on courses;          create policy c_write     on courses         for all using (has_perm('content')) with check (has_perm('content'));
drop policy if exists u_write     on units;            create policy u_write     on units           for all using (has_perm('content')) with check (has_perm('content'));

drop policy if exists l_read      on lectures;         create policy l_read      on lectures        for select using (exists(select 1 from units u where u.id = unit_id and has_access(u.course_id, u.id)));
drop policy if exists l_write     on lectures;         create policy l_write     on lectures        for all using (has_perm('content')) with check (has_perm('content'));
drop policy if exists qz_read     on quizzes;          create policy qz_read     on quizzes         for select using (exists(select 1 from lectures l join units u on u.id = l.unit_id where l.id = lecture_id and has_access(u.course_id, u.id)));
drop policy if exists qz_write    on quizzes;          create policy qz_write    on quizzes         for all using (has_perm('content')) with check (has_perm('content'));
drop policy if exists qs_read     on questions;        create policy qs_read     on questions       for select using (exists(select 1 from quizzes z join lectures l on l.id = z.lecture_id join units u on u.id = l.unit_id where z.id = quiz_id and has_access(u.course_id, u.id)));
drop policy if exists qs_write    on questions;        create policy qs_write    on questions       for all using (has_perm('content')) with check (has_perm('content'));
drop policy if exists qk_write    on question_keys;    create policy qk_write    on question_keys   for all using (has_perm('content')) with check (has_perm('content'));
drop policy if exists qa_own      on quiz_attempts;    create policy qa_own      on quiz_attempts   for select using (user_id = auth.uid());
drop policy if exists ac_read     on activation_codes; create policy ac_read     on activation_codes for select using (has_perm('codes'));
drop policy if exists en_own      on enrollments;      create policy en_own      on enrollments     for select using (user_id = auth.uid() or has_perm('sessions'));
drop policy if exists audit_read  on audit_log;        create policy audit_read  on audit_log       for select using (is_super());
drop policy if exists attempts_read on code_attempts;  create policy attempts_read on code_attempts for select using (has_perm('codes'));

-- ============================ 8) STORAGE (private bucket for PDFs) ============================
insert into storage.buckets (id, name, public) values ('lecture-pdfs', 'lecture-pdfs', false) on conflict (id) do nothing;
drop policy if exists pdf_admin_all on storage.objects;
create policy pdf_admin_all on storage.objects for all
  using (bucket_id = 'lecture-pdfs' and has_perm('content')) with check (bucket_id = 'lecture-pdfs' and has_perm('content'));
-- students never touch the bucket: they get 90-second signed URLs from the Edge Function

-- ============================ 9) REALTIME (instant logout on the old device) ============================
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles') then
    alter publication supabase_realtime add table public.profiles;
  end if;
end $$;

-- ============================ DONE — quick check ============================
-- select count(*) as courses_count from courses;                 -- must be 0 (all three stages empty)
-- select tablename from pg_tables where schemaname = 'public' order by 1;
