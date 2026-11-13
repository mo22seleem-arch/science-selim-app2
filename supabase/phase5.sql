-- ============ Phase 5: hardening (run after phase3.sql) ============

-- ---------- audit log ----------
create table audit_log (
  id bigserial primary key, actor uuid, actor_name text,
  action text not null, target text, meta jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index on audit_log(created_at desc);
alter table audit_log enable row level security;
create policy audit_read on audit_log for select using (is_super());   -- nobody can write/delete from the client

create function log_audit(p_action text, p_target text, p_meta jsonb default '{}'::jsonb) returns void
language sql security definer set search_path=public as $$
  insert into audit_log(actor, actor_name, action, target, meta)
  values (auth.uid(), (select full_name from profiles where id=auth.uid()), p_action, p_target, p_meta) $$;
revoke all on function log_audit(text,text,jsonb) from public, anon, authenticated;  -- internal only

create function audit_content() returns trigger language plpgsql security definer set search_path=public as $$
declare v jsonb := case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  perform log_audit(tg_table_name||'.'||lower(tg_op), v->>'id', jsonb_build_object('title', v->>'title'));
  return null;
end $$;
create trigger audit_courses  after insert or update or delete on courses  for each row execute function audit_content();
create trigger audit_units    after insert or update or delete on units    for each row execute function audit_content();
create trigger audit_lectures after insert or update or delete on lectures for each row execute function audit_content();

-- ---------- redeem rate-limit (failures must be LOGGED, so we return an error code instead of raising: a raise would roll the log back) ----------
create table code_attempts (
  id bigserial primary key, user_id uuid not null references profiles on delete cascade,
  code_tried text, success boolean not null, error text, created_at timestamptz not null default now()
);
create index on code_attempts(user_id, created_at desc);
alter table code_attempts enable row level security;
create policy attempts_read on code_attempts for select using (has_perm('codes'));

drop function if exists redeem_code(text, uuid, uuid);
create function redeem_code(p_code text, p_course uuid, p_unit uuid) returns text
language plpgsql security definer set search_path=public as $$
declare c activation_codes; v_dev text; v_fail int; v_err text;
begin
  if auth.uid() is null then return 'not_authenticated'; end if;
  select active_device_id into v_dev from profiles where id=auth.uid() and not is_banned;
  if v_dev is null then return 'no_active_device'; end if;
  select count(*) into v_fail from code_attempts
    where user_id=auth.uid() and not success and created_at > now() - interval '15 minutes';
  if v_fail >= 5 then return 'too_many_attempts'; end if;

  select * into c from activation_codes where code=upper(trim(p_code)) for update;
  if not found then v_err := 'code_invalid';
  elsif c.status <> 'unused' then v_err := 'code_used';
  elsif c.course_id is distinct from p_course or c.unit_id is distinct from p_unit then v_err := 'code_wrong_target';
  elsif c.redeem_before is not null and c.redeem_before < now() then v_err := 'code_expired';
  end if;
  if v_err is not null then
    insert into code_attempts(user_id, code_tried, success, error) values (auth.uid(), left(coalesce(p_code,''),40), false, v_err);
    return v_err;
  end if;

  insert into enrollments(user_id,course_id,unit_id,code_id,device_id,ends_at)
    values (auth.uid(),c.course_id,c.unit_id,c.id,v_dev, case when c.duration='timed' then now()+make_interval(days=>c.duration_days) end);
  update activation_codes set status='used', used_by=auth.uid(), used_at=now(), used_device_id=v_dev where id=c.id;
  insert into code_attempts(user_id, code_tried, success) values (auth.uid(), c.code, true);
  return 'ok';
end $$;

-- ---------- audited admin functions (same signatures as before) ----------
create or replace function admin_generate_codes(p_count int, p_course uuid, p_unit uuid, p_duration duration_type,
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
  perform log_audit('codes.generate', v_batch::text, jsonb_build_object('count',p_count,'course',p_course,'unit',p_unit,'duration',p_duration,'days',p_days));
end $$;

create or replace function admin_revoke_code(p_id uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  if not has_perm('codes') then raise exception 'forbidden'; end if;
  update activation_codes set status='revoked' where id=p_id and status='unused';
  perform log_audit('codes.revoke', p_id::text);
end $$;

create or replace function admin_reset_device(p_user uuid) returns void language plpgsql security definer set search_path=public, auth as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  update profiles set active_device_id=null where id=p_user;
  delete from device_sessions where user_id=p_user;
  delete from auth.sessions where user_id=p_user;
  perform log_audit('student.device_reset', p_user::text);
end $$;

create or replace function admin_set_role(p_user uuid, p_role user_role, p_perms text[]) returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  if p_role = 'super_admin' then raise exception 'cannot_create_super_admin'; end if;
  if (select role from profiles where id=p_user)='super_admin' then raise exception 'owner_protected'; end if;
  update profiles set role=p_role, permissions=coalesce(p_perms,'{}') where id=p_user;
  perform log_audit('staff.set_role', p_user::text, jsonb_build_object('role',p_role,'perms',p_perms));
end $$;

create or replace function admin_set_ban(p_user uuid, p_ban boolean) returns void language plpgsql security definer set search_path=public, auth as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  if (select role from profiles where id=p_user)='super_admin' then raise exception 'owner_protected'; end if;
  update profiles set is_banned=p_ban where id=p_user;
  if p_ban then delete from auth.sessions where user_id=p_user; end if;
  perform log_audit(case when p_ban then 'student.ban' else 'student.unban' end, p_user::text);
end $$;

-- account-sharing signal: every switch between two DIFFERENT devices is logged ('device.switch')
create or replace function register_device(p_device_id text, p_device_name text default null) returns void
language plpgsql security definer set search_path=public, auth as $$
declare v_sid uuid := nullif(auth.jwt()->>'session_id','')::uuid; v_old text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select active_device_id into v_old from profiles where id=auth.uid();
  if (select is_banned from profiles where id=auth.uid()) then raise exception 'banned'; end if;
  update profiles set active_device_id=p_device_id where id=auth.uid();
  insert into device_sessions(user_id,device_id,device_name) values (auth.uid(),p_device_id,p_device_name)
    on conflict (user_id) do update set device_id=excluded.device_id, device_name=excluded.device_name, last_seen=now();
  delete from auth.sessions where user_id=auth.uid() and id <> v_sid;
  if v_old is not null and v_old <> p_device_id then
    perform log_audit('device.switch', auth.uid()::text, jsonb_build_object('from',v_old,'to',p_device_id,'name',p_device_name));
  end if;
end $$;

-- ---------- Play Integrity (server-verified) ----------
alter table profiles add column if not exists integrity_ok_until timestamptz;
create table integrity_nonces (
  user_id uuid primary key references profiles on delete cascade,
  nonce text not null, created_at timestamptz not null default now()
);
alter table integrity_nonces enable row level security;   -- no policies: only the Edge Function (service role) touches it
