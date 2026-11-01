-- DK Trading Academy: expire course access at 12:00 AM IST on the 31st day.
-- Purchase date is Day 1: a purchase on Nov 1 expires at Dec 1, 00:00 IST.
-- This migration changes only content-access policies; it does not delete enrollments,
-- payments, lesson progress, videos, or PDFs.

-- Lesson resource metadata is readable only while the matching purchase is active.
drop policy if exists "enrolled students read lesson resources" on public.academy_lesson_resources;
create policy "active students read lesson resources"
on public.academy_lesson_resources for select to authenticated
using (
  exists (
    select 1
    from public.course_enrollments e
    where e.user_id = auth.uid()
      and (e.course_id = academy_lesson_resources.course_id
           or e.course_id = 'all-courses-combo')
      and now() < (((e.created_at at time zone 'Asia/Kolkata')::date + 30)::timestamp at time zone 'Asia/Kolkata')
  )
);

-- Published PDFs are readable only during the active 31-day access period.
drop policy if exists "enrolled students read published course PDFs" on public.academy_course_pdfs;
drop policy if exists "active students read published course PDFs" on public.academy_course_pdfs;
create policy "active students read published course PDFs"
on public.academy_course_pdfs for select to authenticated
using (
  is_published = true
  and exists (
    select 1
    from public.course_enrollments e
    where e.user_id = auth.uid()
      and (e.course_id = academy_course_pdfs.course_id
           or e.course_id = 'all-courses-combo')
      and now() < (((e.created_at at time zone 'Asia/Kolkata')::date + 30)::timestamp at time zone 'Asia/Kolkata')
  )
);

-- Private PDF objects use the same active enrollment and published-resource check.
drop policy if exists "enrolled students view published academy PDFs" on storage.objects;
drop policy if exists "active students view published academy PDFs" on storage.objects;
create policy "active students view published academy PDFs"
on storage.objects for select to authenticated
using (
  bucket_id = 'academy-pdfs'
  and exists (
    select 1
    from public.academy_course_pdfs p
    join public.course_enrollments e
      on e.user_id = auth.uid()
     and (e.course_id = p.course_id or e.course_id = 'all-courses-combo')
    where p.storage_path = storage.objects.name
      and p.is_published = true
      and now() < (((e.created_at at time zone 'Asia/Kolkata')::date + 30)::timestamp at time zone 'Asia/Kolkata')
  )
);

-- Private uploaded lesson videos require an active enrollment in the matching course
-- (or an active all-courses-combo enrollment) and a published lesson.
drop policy if exists "enrolled students view published academy videos" on storage.objects;
drop policy if exists "active students view published academy videos" on storage.objects;
create policy "active students view published academy videos"
on storage.objects for select to authenticated
using (
  bucket_id = 'academy-videos'
  and exists (
    select 1
    from public.academy_lesson_resources r
    join public.academy_course_lessons l
      on l.course_id = r.course_id and l.lesson_number = r.lesson_number
    join public.course_enrollments e
      on e.user_id = auth.uid()
     and (e.course_id = r.course_id or e.course_id = 'all-courses-combo')
    where r.video_storage_path = storage.objects.name
      and l.is_published = true
      and now() < (((e.created_at at time zone 'Asia/Kolkata')::date + 30)::timestamp at time zone 'Asia/Kolkata')
  )
);
