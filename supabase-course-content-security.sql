-- DK Trading Academy: secure course videos and PDFs
-- Run once in Supabase SQL Editor. Does not alter payments or lesson_progress.

create table if not exists public.academy_lesson_resources (
  course_id text not null,
  lesson_number integer not null,
  video_url text,
  updated_at timestamptz not null default now(),
  primary key (course_id, lesson_number)
);

create table if not exists public.academy_course_pdfs (
  id uuid primary key default gen_random_uuid(),
  course_id text not null,
  title text not null,
  description text,
  storage_path text not null unique,
  is_published boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.academy_lesson_resources enable row level security;
alter table public.academy_course_pdfs enable row level security;

drop policy if exists "admins manage lesson resources" on public.academy_lesson_resources;
create policy "admins manage lesson resources"
on public.academy_lesson_resources for all to authenticated
using (exists (select 1 from public.academy_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.academy_admins a where a.user_id = auth.uid()));

drop policy if exists "enrolled students read lesson resources" on public.academy_lesson_resources;
create policy "enrolled students read lesson resources"
on public.academy_lesson_resources for select to authenticated
using (
  exists (
    select 1 from public.course_enrollments e
    where e.user_id = auth.uid()
      and (e.course_id = academy_lesson_resources.course_id
           or e.course_id = 'all-courses-combo')
  )
);

drop policy if exists "admins manage course PDFs" on public.academy_course_pdfs;
create policy "admins manage course PDFs"
on public.academy_course_pdfs for all to authenticated
using (exists (select 1 from public.academy_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.academy_admins a where a.user_id = auth.uid()));

drop policy if exists "enrolled students read published course PDFs" on public.academy_course_pdfs;
create policy "enrolled students read published course PDFs"
on public.academy_course_pdfs for select to authenticated
using (
  is_published = true
  and exists (
    select 1 from public.course_enrollments e
    where e.user_id = auth.uid()
      and (e.course_id = academy_course_pdfs.course_id
           or e.course_id = 'all-courses-combo')
  )
);

-- Keep legacy lesson titles available, but remove video URLs from the public-readable table.
update public.academy_course_lessons
set video_url = null
where video_url is not null;

-- Private bucket: PDFs are served only through authenticated, policy-checked access.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('academy-pdfs', 'academy-pdfs', false, 52428800, array['application/pdf'])
on conflict (id) do update
set public = false, file_size_limit = 52428800, allowed_mime_types = array['application/pdf'];

drop policy if exists "admins manage academy PDFs storage" on storage.objects;
create policy "admins manage academy PDFs storage"
on storage.objects for all to authenticated
using (
  bucket_id = 'academy-pdfs'
  and exists (select 1 from public.academy_admins a where a.user_id = auth.uid())
)
with check (
  bucket_id = 'academy-pdfs'
  and exists (select 1 from public.academy_admins a where a.user_id = auth.uid())
);

drop policy if exists "enrolled students view published academy PDFs" on storage.objects;
create policy "enrolled students view published academy PDFs"
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
  )
);
