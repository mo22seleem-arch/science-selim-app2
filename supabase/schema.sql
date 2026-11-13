-- ============ Science with Mohamed Selim : Supabase schema (Phase 1) ============
create extension if not exists pgcrypto;
create type user_role     as enum ('student','sub_admin','super_admin');
create type access_type   as enum ('free','paid');
create type duration_type as enum ('permanent','timed');
create type code_status   as enum ('unused','used','revoked');

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  phone text not null unique check (phone ~ '^01[0125][0-9]{8}$'),
  role user_role not null default 'student',
  permissions text[] not null default '{}',  -- 'codes','content','settings','sessions'
  active_device_id text,
  is_banned boolean not null default false,
  created_at timestamptz not null default now()
);
-- Only ONE super admin can ever exist
create unique index one_super_admin on profiles(role) where role = 'super_admin';

create table device_sessions (
  user_id uuid primary key references profiles on delete cascade,
  device_id text not null, device_name text,
  last_seen timestamptz not null default now()
);

create table courses (
  id uuid primary key default gen_random_uuid(),
  title text not null, description text, thumbnail_url text,
  access access_type not null default 'paid', sort_order int default 0,
  created_at timestamptz default now()
);
create table units (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses on delete cascade,
  title text not null, access access_type not null default 'paid', sort_order int default 0
);
create table lectures (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references units on delete cascade,
  title text not null, sort_order int default 0,
  video_provider text check (video_provider in ('bunny','vdocipher','hls')),
  video_ref text,            -- HLS url / VdoCipher video id (token minted server-side later)
  pdf_path text              -- private storage bucket path (signed URL, in-app viewer only)
);
create table quizzes (
  id uuid primary key default gen_random_uuid(),
  lecture_id uuid not null unique references lectures on delete cascade,
  title text, pass_percent int default 50
);
create table questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes on delete cascade,
  body text not null, options jsonb not null, sort_order int default 0
);
-- correct answers live apart: NO select policy => never reaches clients
create table question_keys (
  question_id uuid primary key references questions on delete cascade,
  correct_index int not null
);
create table quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles, quiz_id uuid not null references quizzes,
  score_percent int not null, created_at timestamptz default now()
);

create table activation_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  course_id uuid references courses, unit_id uuid references units,
  check ((course_id is null) <> (unit_id is null)),      -- tied to exactly one target
  duration duration_type not null, duration_days int check (duration = 'permanent' or duration_days > 0),
  redeem_before timestamptz,                              -- code expiry
  status code_status not null default 'unused',
  batch_id uuid, created_by uuid references profiles, created_at timestamptz default now(),
  used_by uuid references profiles, used_at timestamptz, used_device_id text
);
create table enrollments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  course_id uuid references courses, unit_id uuid references units,
  code_id uuid references activation_codes, device_id text,
  starts_at timestamptz default now(), ends_at timestamptz       -- null = permanent
);
create index on enrollments(user_id);

-- ---------------- helpers ----------------
create function is_super() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='super_admin') $$;

create function has_perm(p text) returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and not is_banned
   and (role='super_admin' or (role='sub_admin' and p = any(permissions)))) $$;

create function has_access(p_course uuid, p_unit uuid) returns boolean language sql stable security definer set search_path=public as $$
  select has_perm('content') or exists(
    select 1 from courses c where c.id=p_course and c.access='free')
  or exists(select 1 from units u where u.id=p_unit and u.access='free')
  or exists(select 1 from enrollments e where e.user_id=auth.uid()
      and (e.course_id=p_course or e.unit_id=p_unit) and (e.ends_at is null or e.ends_at>now()))
$$;

-- ---------------- signup trigger (validation + hardcoded owner) ----------------
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare v_name text := trim(regexp_replace(new.raw_user_meta_data->>'full_name','\s+',' ','g'));
        v_phone text := new.raw_user_meta_data->>'phone'; v_role user_role := 'student';
begin
  if v_phone !~ '^01[0125][0-9]{8}$' then raise exception 'invalid_phone'; end if;
  if v_phone = '01091277447' then
     v_role := 'super_admin'; v_name := 'MOHAMED SELIM';
  elsif coalesce(array_length(string_to_array(v_name,' '),1),0) < 3 then
     raise exception 'triple_name_required';
  end if;
  insert into profiles(id, full_name, phone, role) values (new.id, v_name, v_phone, v_role);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- ---------------- single-device enforcement ----------------
create function register_device(p_device_id text, p_device_name text default null) returns void
language plpgsql security definer set search_path=public, auth as $$
declare v_sid uuid := nullif(auth.jwt()->>'session_id','')::uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if (select is_banned from profiles where id=auth.uid()) then raise exception 'banned'; end if;
  update profiles set active_device_id=p_device_id where id=auth.uid();   -- fires Realtime to old phone
  insert into device_sessions(user_id,device_id,device_name) values (auth.uid(),p_device_id,p_device_name)
    on conflict (user_id) do update set device_id=excluded.device_id, device_name=excluded.device_name, last_seen=now();
  delete from auth.sessions where user_id=auth.uid() and id <> v_sid;     -- kill refresh tokens on old device
end $$;

create function admin_reset_device(p_user uuid) returns void language plpgsql security definer set search_path=public, auth as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  update profiles set active_device_id=null where id=p_user;
  delete from device_sessions where user_id=p_user;
  delete from auth.sessions where user_id=p_user;
end $$;

create function admin_set_role(p_user uuid, p_role user_role, p_perms text[]) returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  if p_role = 'super_admin' then raise exception 'cannot_create_super_admin'; end if;
  if (select role from profiles where id=p_user)='super_admin' then raise exception 'owner_protected'; end if;
  update profiles set role=p_role, permissions=coalesce(p_perms,'{}') where id=p_user;
end $$;

-- ---------------- activation codes ----------------
create function admin_generate_codes(p_count int, p_course uuid, p_unit uuid, p_duration duration_type,
  p_days int, p_redeem_before timestamptz) returns setof text language plpgsql security definer set search_path=public as $$
declare v_batch uuid := gen_random_uuid(); v_code text;
begin
  if not has_perm('codes') then raise exception 'forbidden'; end if;
  if p_count not between 1 and 500 then raise exception 'bad_count'; end if;
  for i in 1..p_count loop
    v_code := upper(encode(gen_random_bytes(8),'hex'));
    insert into activation_codes(code,course_id,unit_id,duration,duration_days,redeem_before,batch_id,created_by)
      values (v_code,p_course,p_unit,p_duration,p_days,p_redeem_before,v_batch,auth.uid());
    return next v_code;
  end loop;
end $$;

create function redeem_code(p_code text, p_course uuid, p_unit uuid) returns void
language plpgsql security definer set search_path=public as $$
declare c activation_codes; v_dev text;
begin
  select active_device_id into v_dev from profiles where id=auth.uid() and not is_banned;
  if v_dev is null then raise exception 'no_active_device'; end if;
  select * into c from activation_codes where code=upper(trim(p_code)) for update;
  if not found then raise exception 'code_invalid'; end if;                                  -- (1) exists
  if c.status <> 'unused' then raise exception 'code_used'; end if;                          -- (2) unused
  if c.course_id is distinct from p_course or c.unit_id is distinct from p_unit
     then raise exception 'code_wrong_target'; end if;                                       -- (3) matches target
  if c.redeem_before is not null and c.redeem_before < now() then raise exception 'code_expired'; end if; -- (4)
  insert into enrollments(user_id,course_id,unit_id,code_id,device_id,ends_at)
    values (auth.uid(),c.course_id,c.unit_id,c.id,v_dev,
            case when c.duration='timed' then now()+make_interval(days=>c.duration_days) end);
  update activation_codes set status='used', used_by=auth.uid(), used_at=now(), used_device_id=v_dev where id=c.id;
end $$;

-- ---------------- quiz grading (server-side) ----------------
create function submit_quiz(p_quiz uuid, p_answers jsonb) returns int language plpgsql security definer set search_path=public as $$
declare v_total int; v_ok int; v_pct int;
begin
  select count(*) into v_total from questions where quiz_id=p_quiz;
  select count(*) into v_ok from questions q join question_keys k on k.question_id=q.id
    where q.quiz_id=p_quiz and (p_answers->>(q.id::text))::int = k.correct_index;
  v_pct := case when v_total=0 then 0 else round(100.0*v_ok/v_total) end;
  insert into quiz_attempts(user_id,quiz_id,score_percent) values (auth.uid(),p_quiz,v_pct);
  return v_pct;
end $$;

-- ---------------- RLS ----------------
alter table profiles enable row level security;  alter table device_sessions enable row level security;
alter table courses enable row level security;   alter table units enable row level security;
alter table lectures enable row level security;  alter table quizzes enable row level security;
alter table questions enable row level security; alter table question_keys enable row level security;
alter table quiz_attempts enable row level security; alter table activation_codes enable row level security;
alter table enrollments enable row level security;

revoke update, insert, delete on profiles from authenticated;   -- profile changes only via RPCs
create policy p_self   on profiles for select using (id=auth.uid() or has_perm('sessions'));
create policy ds_read  on device_sessions for select using (has_perm('sessions'));
create policy c_read   on courses  for select using (auth.uid() is not null);   -- catalogue visible, content locked
create policy u_read   on units    for select using (auth.uid() is not null);
create policy c_write  on courses  for all using (has_perm('content')) with check (has_perm('content'));
create policy u_write  on units    for all using (has_perm('content')) with check (has_perm('content'));
create policy l_read   on lectures for select using (exists(select 1 from units u where u.id=unit_id and has_access(u.course_id,u.id)));
create policy l_write  on lectures for all using (has_perm('content')) with check (has_perm('content'));
create policy qz_read  on quizzes  for select using (exists(select 1 from lectures l join units u on u.id=l.unit_id where l.id=lecture_id and has_access(u.course_id,u.id)));
create policy qz_write on quizzes  for all using (has_perm('content')) with check (has_perm('content'));
create policy qs_read  on questions for select using (exists(select 1 from quizzes z join lectures l on l.id=z.lecture_id join units u on u.id=l.unit_id where z.id=quiz_id and has_access(u.course_id,u.id)));
create policy qs_write on questions for all using (has_perm('content')) with check (has_perm('content'));
create policy qk_write on question_keys for all using (has_perm('content')) with check (has_perm('content'));
create policy qa_own   on quiz_attempts for select using (user_id=auth.uid());
create policy ac_read  on activation_codes for select using (has_perm('codes'));   -- students use redeem_code() only
create policy en_own   on enrollments for select using (user_id=auth.uid() or has_perm('sessions'));
