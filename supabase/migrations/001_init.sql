create extension if not exists "pgcrypto";
create extension if not exists "citext";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.centers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'America/New_York',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  center_id uuid not null references public.centers(id) on delete cascade,
  role text not null check (role in ('admin', 'teacher', 'parent')),
  full_name text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.guardians (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  full_name text not null,
  email citext,
  phone text,
  relationship text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  birth_date date not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  name text not null,
  age_group text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.classroom_staff (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  teacher_profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (classroom_id, teacher_profile_id)
);

create table if not exists public.enrollments (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  start_date date not null,
  end_date date,
  status text not null default 'active' check (status in ('active', 'ended')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.tuition_plans (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  name text not null,
  amount_cents integer not null check (amount_cents >= 0),
  cadence text not null check (cadence in ('weekly', 'monthly')),
  effective_date date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  tuition_plan_id uuid references public.tuition_plans(id) on delete set null,
  issue_date date not null,
  due_date date not null,
  amount_cents integer not null check (amount_cents >= 0),
  status text not null default 'draft' check (status in ('draft', 'sent', 'paid', 'overdue')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  amount_cents integer not null check (amount_cents >= 0),
  paid_at timestamptz not null default timezone('utc', now()),
  method text,
  reference text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  title text not null,
  body text not null,
  published_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.notice_recipients (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  notice_id uuid not null references public.notices(id) on delete cascade,
  family_id uuid references public.families(id) on delete cascade,
  child_id uuid references public.children(id) on delete cascade,
  guardian_id uuid references public.guardians(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.daily_notes (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  classroom_id uuid references public.classrooms(id) on delete set null,
  note_date date not null,
  content text not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.progress_reports (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  report_period daterange not null,
  summary text not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.signature_requests (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  child_id uuid references public.children(id) on delete cascade,
  family_id uuid references public.families(id) on delete cascade,
  title text not null,
  document_url text,
  due_date date,
  status text not null default 'pending' check (status in ('pending', 'signed', 'expired')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.signatures (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  signature_request_id uuid not null references public.signature_requests(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id) on delete cascade,
  signed_at timestamptz not null default timezone('utc', now()),
  ip_address inet,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (signature_request_id, guardian_id)
);

create table if not exists public.email_templates (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  key text not null,
  subject text not null,
  html_body text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (center_id, key)
);

create table if not exists public.email_logs (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references public.centers(id) on delete cascade,
  to_email citext not null,
  subject text not null,
  template_key text,
  provider_message_id text,
  status text not null check (status in ('sent', 'failed')),
  metadata jsonb not null default '{}'::jsonb,
  sent_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_profiles_center_role on public.profiles(center_id, role);
create index if not exists idx_guardians_family on public.guardians(family_id);
create index if not exists idx_children_family on public.children(family_id);
create index if not exists idx_classrooms_center on public.classrooms(center_id);
create index if not exists idx_classroom_staff_teacher on public.classroom_staff(teacher_profile_id);
create index if not exists idx_enrollments_child_status on public.enrollments(child_id, status);
create index if not exists idx_invoices_family_due on public.invoices(family_id, due_date);
create index if not exists idx_payments_invoice on public.payments(invoice_id);
create index if not exists idx_notices_center_published on public.notices(center_id, published_at);
create index if not exists idx_notice_recipients_notice on public.notice_recipients(notice_id);
create index if not exists idx_daily_notes_child_date on public.daily_notes(child_id, note_date);
create index if not exists idx_progress_reports_child on public.progress_reports(child_id);
create index if not exists idx_signature_requests_family on public.signature_requests(family_id);
create index if not exists idx_signatures_request on public.signatures(signature_request_id);
create index if not exists idx_email_logs_center_sent on public.email_logs(center_id, sent_at desc);

create trigger set_updated_at_centers before update on public.centers for each row execute function public.set_updated_at();
create trigger set_updated_at_profiles before update on public.profiles for each row execute function public.set_updated_at();
create trigger set_updated_at_families before update on public.families for each row execute function public.set_updated_at();
create trigger set_updated_at_guardians before update on public.guardians for each row execute function public.set_updated_at();
create trigger set_updated_at_children before update on public.children for each row execute function public.set_updated_at();
create trigger set_updated_at_classrooms before update on public.classrooms for each row execute function public.set_updated_at();
create trigger set_updated_at_classroom_staff before update on public.classroom_staff for each row execute function public.set_updated_at();
create trigger set_updated_at_enrollments before update on public.enrollments for each row execute function public.set_updated_at();
create trigger set_updated_at_tuition_plans before update on public.tuition_plans for each row execute function public.set_updated_at();
create trigger set_updated_at_invoices before update on public.invoices for each row execute function public.set_updated_at();
create trigger set_updated_at_payments before update on public.payments for each row execute function public.set_updated_at();
create trigger set_updated_at_notices before update on public.notices for each row execute function public.set_updated_at();
create trigger set_updated_at_notice_recipients before update on public.notice_recipients for each row execute function public.set_updated_at();
create trigger set_updated_at_daily_notes before update on public.daily_notes for each row execute function public.set_updated_at();
create trigger set_updated_at_progress_reports before update on public.progress_reports for each row execute function public.set_updated_at();
create trigger set_updated_at_signature_requests before update on public.signature_requests for each row execute function public.set_updated_at();
create trigger set_updated_at_signatures before update on public.signatures for each row execute function public.set_updated_at();
create trigger set_updated_at_email_templates before update on public.email_templates for each row execute function public.set_updated_at();
create trigger set_updated_at_email_logs before update on public.email_logs for each row execute function public.set_updated_at();

create or replace function public.current_center_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select center_id from public.profiles where id = auth.uid();
$$;

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_role() = 'admin';
$$;

create or replace function public.teacher_has_child(target_child_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classroom_staff cs
    join public.enrollments e on e.classroom_id = cs.classroom_id and e.status = 'active'
    where cs.teacher_profile_id = auth.uid()
      and e.child_id = target_child_id
  );
$$;

create or replace function public.parent_owns_child(target_child_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.children c
    join public.guardians g on g.family_id = c.family_id and g.profile_id = auth.uid()
    where c.id = target_child_id
  );
$$;

alter table public.centers enable row level security;
alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.guardians enable row level security;
alter table public.children enable row level security;
alter table public.classrooms enable row level security;
alter table public.classroom_staff enable row level security;
alter table public.enrollments enable row level security;
alter table public.tuition_plans enable row level security;
alter table public.invoices enable row level security;
alter table public.payments enable row level security;
alter table public.notices enable row level security;
alter table public.notice_recipients enable row level security;
alter table public.daily_notes enable row level security;
alter table public.progress_reports enable row level security;
alter table public.signature_requests enable row level security;
alter table public.signatures enable row level security;
alter table public.email_templates enable row level security;
alter table public.email_logs enable row level security;

create policy centers_admin on public.centers for all using (public.is_admin() and id = public.current_center_id()) with check (public.is_admin() and id = public.current_center_id());
create policy profiles_by_center on public.profiles for all using (center_id = public.current_center_id() and (public.is_admin() or id = auth.uid())) with check (center_id = public.current_center_id() and public.is_admin());
create policy families_center_access on public.families for all using (
  center_id = public.current_center_id() and (
    public.is_admin()
    or exists (select 1 from public.guardians g where g.family_id = id and g.profile_id = auth.uid())
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy guardians_access on public.guardians for all using (
  center_id = public.current_center_id() and (
    public.is_admin()
    or profile_id = auth.uid()
    or exists (select 1 from public.classroom_staff cs join public.enrollments e on e.classroom_id = cs.classroom_id where cs.teacher_profile_id = auth.uid() and e.child_id in (select c.id from public.children c where c.family_id = guardians.family_id))
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy children_access on public.children for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or public.teacher_has_child(id) or public.parent_owns_child(id)
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy classrooms_access on public.classrooms for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or exists (select 1 from public.classroom_staff cs where cs.classroom_id = id and cs.teacher_profile_id = auth.uid())
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy classroom_staff_access on public.classroom_staff for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or teacher_profile_id = auth.uid()
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy enrollments_access on public.enrollments for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or public.teacher_has_child(child_id) or public.parent_owns_child(child_id)
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy tuition_plans_access on public.tuition_plans for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or public.parent_owns_child(child_id)
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy invoices_access on public.invoices for all using (
  center_id = public.current_center_id() and (
    public.is_admin()
    or exists (select 1 from public.guardians g where g.family_id = invoices.family_id and g.profile_id = auth.uid())
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy payments_access on public.payments for all using (
  center_id = public.current_center_id() and (
    public.is_admin()
    or exists (select 1 from public.invoices i join public.guardians g on g.family_id = i.family_id where i.id = payments.invoice_id and g.profile_id = auth.uid())
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy notices_access on public.notices for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or public.current_role() in ('teacher', 'parent')
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy notice_recipients_access on public.notice_recipients for all using (
  center_id = public.current_center_id() and (
    public.is_admin()
    or exists (select 1 from public.guardians g where g.id = notice_recipients.guardian_id and g.profile_id = auth.uid())
    or exists (select 1 from public.children c where c.id = notice_recipients.child_id and public.teacher_has_child(c.id))
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy daily_notes_access on public.daily_notes for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or public.teacher_has_child(child_id) or public.parent_owns_child(child_id)
  )
) with check (
  center_id = public.current_center_id() and (
    public.is_admin() or public.teacher_has_child(child_id)
  )
);
create policy progress_reports_access on public.progress_reports for all using (
  center_id = public.current_center_id() and (
    public.is_admin() or public.teacher_has_child(child_id) or public.parent_owns_child(child_id)
  )
) with check (
  center_id = public.current_center_id() and (
    public.is_admin() or public.teacher_has_child(child_id)
  )
);
create policy signature_requests_access on public.signature_requests for all using (
  center_id = public.current_center_id() and (
    public.is_admin()
    or (child_id is not null and public.teacher_has_child(child_id))
    or exists (select 1 from public.guardians g where g.family_id = signature_requests.family_id and g.profile_id = auth.uid())
  )
) with check (center_id = public.current_center_id() and public.is_admin());
create policy signatures_access on public.signatures for all using (
  center_id = public.current_center_id() and (
    public.is_admin()
    or exists (select 1 from public.guardians g where g.id = signatures.guardian_id and g.profile_id = auth.uid())
  )
) with check (
  center_id = public.current_center_id() and (
    public.is_admin()
    or exists (select 1 from public.guardians g where g.id = signatures.guardian_id and g.profile_id = auth.uid())
  )
);
create policy email_templates_access on public.email_templates for all using (center_id = public.current_center_id() and public.is_admin()) with check (center_id = public.current_center_id() and public.is_admin());
create policy email_logs_access on public.email_logs for all using (center_id = public.current_center_id() and public.is_admin()) with check (center_id = public.current_center_id() and public.is_admin());
