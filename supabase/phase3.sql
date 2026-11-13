-- ============ Phase 3+4 (run after phase2.sql) ============
-- private bucket for PDFs: students NEVER get direct storage access, only short-lived signed URLs from the Edge Function
insert into storage.buckets (id, name, public) values ('lecture-pdfs','lecture-pdfs', false) on conflict do nothing;
create policy pdf_admin_all on storage.objects for all
  using (bucket_id='lecture-pdfs' and has_perm('content')) with check (bucket_id='lecture-pdfs' and has_perm('content'));

create or replace function lecture_access(p_lecture uuid) returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from lectures l join units u on u.id=l.unit_id
                where l.id=p_lecture and has_access(u.course_id,u.id)) $$;

-- Auto-grading with access check; returns the full review (correct answers are revealed only AFTER submitting)
drop function if exists submit_quiz(uuid, jsonb);
create function submit_quiz(p_quiz uuid, p_answers jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_pass int; v_total int; v_ok int; v_pct int; v_review jsonb;
begin
  if not exists(select 1 from quizzes z join lectures l on l.id=z.lecture_id join units u on u.id=l.unit_id
                where z.id=p_quiz and has_access(u.course_id,u.id)) then raise exception 'forbidden'; end if;
  select pass_percent into v_pass from quizzes where id=p_quiz;
  with r as (
    select q.id, q.sort_order, k.correct_index,
           case when (p_answers->>(q.id::text)) ~ '^[0-9]+$' then (p_answers->>(q.id::text))::int end as chosen
    from questions q join question_keys k on k.question_id=q.id where q.quiz_id=p_quiz)
  select count(*), count(*) filter (where chosen = correct_index),
         coalesce(jsonb_agg(jsonb_build_object('id',id,'correct_index',correct_index,'chosen',chosen) order by sort_order),'[]'::jsonb)
    into v_total, v_ok, v_review from r;
  if v_total = 0 then raise exception 'empty_quiz'; end if;
  v_pct := round(100.0*v_ok/v_total);
  insert into quiz_attempts(user_id,quiz_id,score_percent) values (auth.uid(),p_quiz,v_pct);
  return jsonb_build_object('score',v_pct,'passed',v_pct>=v_pass,'correct',v_ok,'total',v_total,'review',v_review);
end $$;
