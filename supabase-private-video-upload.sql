-- DK Trading Academy: enable private uploaded lesson videos
-- Run once in Supabase SQL Editor. Existing video URL lessons remain supported.

alter table public.academy_lesson_resources
  add column if not exists video_storage_path text;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('academy-videos','academy-videos',false,2147483648,array['video/mp4','video/webm','video/quicktime'])
on conflict (id) do update
set public=false,file_size_limit=2147483648,
    allowed_mime_types=array['video/mp4','video/webm','video/quicktime'];

drop policy if exists "admins manage academy videos storage" on storage.objects;
create policy "admins manage academy videos storage"
on storage.objects for all to authenticated
using (
  bucket_id='academy-videos'
  and exists(select 1 from public.academy_admins a where a.user_id=auth.uid())
)
with check (
  bucket_id='academy-videos'
  and exists(select 1 from public.academy_admins a where a.user_id=auth.uid())
);

drop policy if exists "enrolled students view published academy videos" on storage.objects;
create policy "enrolled students view published academy videos"
on storage.objects for select to authenticated
using (
  bucket_id='academy-videos'
  and exists (
    select 1
    from public.academy_lesson_resources r
    join public.academy_course_lessons l
      on l.course_id=r.course_id and l.lesson_number=r.lesson_number
    join public.course_enrollments e
      on e.user_id=auth.uid()
     and (e.course_id=r.course_id or e.course_id='all-courses-combo')
    where r.video_storage_path=storage.objects.name
      and l.is_published=true
  )
);
