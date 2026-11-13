-- ============ Phase 2 additions (run after schema.sql) ============
create or replace function admin_revoke_code(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not has_perm('codes') then raise exception 'forbidden'; end if;
  update activation_codes set status='revoked' where id=p_id and status='unused';
end $$;

create or replace function admin_set_ban(p_user uuid, p_ban boolean) returns void
language plpgsql security definer set search_path=public, auth as $$
begin
  if not is_super() then raise exception 'forbidden'; end if;
  if (select role from profiles where id=p_user)='super_admin' then raise exception 'owner_protected'; end if;
  update profiles set is_banned=p_ban where id=p_user;
  if p_ban then delete from auth.sessions where user_id=p_user; end if;
end $$;

-- sort/lookup helpers
create index if not exists idx_codes_batch on activation_codes(batch_id, created_at desc);
create index if not exists idx_units_course on units(course_id, sort_order);
