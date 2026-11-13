-- ============ Phase 6: fixed grade levels (run once, after phase5.sql) ============
-- 1 = الأول الإعدادي | 2 = الثاني الإعدادي | 3 = الثالث الإعدادي
-- No courses/subjects are seeded: all three stages start EMPTY.

alter table courses add column if not exists grade smallint;
update courses set grade = 1 where grade is null;          -- only matters if you created test courses earlier
alter table courses alter column grade set not null;
alter table courses add constraint courses_grade_check check (grade in (1, 2, 3));
create index if not exists idx_courses_grade on courses (grade, sort_order);
comment on column courses.grade is '1=prep1, 2=prep2, 3=prep3';

-- Free/Paid already lives in courses.access ('free' | 'paid'); RLS is unchanged:
--   read  : any signed-in user (catalogue visible, paid content stays locked)
--   write : owner, or sub-admins the owner granted the "content" permission (has_perm('content'))

-- OPTIONAL: wipe any test courses so every stage starts empty (also deletes their units/lectures/quizzes/codes!)
-- delete from courses;
