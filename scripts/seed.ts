import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const USERS = {
  admin: { email: "admin@centerhub.local", password: "Passw0rd!123", fullName: "Ava Admin", role: "admin" as const },
  teacher: { email: "teacher@centerhub.local", password: "Passw0rd!123", fullName: "Tom Teacher", role: "teacher" as const },
  parent: { email: "parent@centerhub.local", password: "Passw0rd!123", fullName: "Pia Parent", role: "parent" as const }
};

async function ensureUser(email: string, password: string) {
  const list = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });

  if (list.error) {
    throw list.error;
  }

  const existing = list.data.users.find((user) => user.email?.toLowerCase() === email.toLowerCase());

  if (existing) {
    return existing;
  }

  const created = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  });

  if (created.error || !created.data.user) {
    throw created.error ?? new Error(`Could not create user for ${email}`);
  }

  return created.data.user;
}

async function main() {
  const { data: center } = await supabase
    .from("centers")
    .upsert({ name: "CenterHub Demo Center", timezone: "America/New_York" }, { onConflict: "name" })
    .select("id")
    .single();

  if (!center) {
    throw new Error("Failed to create center");
  }

  const adminUser = await ensureUser(USERS.admin.email, USERS.admin.password);
  const teacherUser = await ensureUser(USERS.teacher.email, USERS.teacher.password);
  const parentUser = await ensureUser(USERS.parent.email, USERS.parent.password);

  await supabase.from("profiles").upsert([
    { id: adminUser.id, center_id: center.id, role: USERS.admin.role, full_name: USERS.admin.fullName },
    { id: teacherUser.id, center_id: center.id, role: USERS.teacher.role, full_name: USERS.teacher.fullName },
    { id: parentUser.id, center_id: center.id, role: USERS.parent.role, full_name: USERS.parent.fullName }
  ]);

  const { data: family } = await supabase
    .from("families")
    .insert({ center_id: center.id, name: "Parent Household" })
    .select("id")
    .single();

  if (!family) throw new Error("Failed to create family");

  const { data: guardian } = await supabase
    .from("guardians")
    .insert({
      center_id: center.id,
      family_id: family.id,
      profile_id: parentUser.id,
      full_name: USERS.parent.fullName,
      email: USERS.parent.email,
      relationship: "Mother"
    })
    .select("id")
    .single();

  const { data: child } = await supabase
    .from("children")
    .insert({
      center_id: center.id,
      family_id: family.id,
      first_name: "Cory",
      last_name: "Child",
      birth_date: "2020-06-15"
    })
    .select("id")
    .single();

  const { data: classroom } = await supabase
    .from("classrooms")
    .insert({ center_id: center.id, name: "Butterflies", age_group: "Pre-K" })
    .select("id")
    .single();

  await supabase.from("classroom_staff").upsert({
    center_id: center.id,
    classroom_id: classroom?.id,
    teacher_profile_id: teacherUser.id
  });

  await supabase.from("enrollments").insert({
    center_id: center.id,
    child_id: child?.id,
    classroom_id: classroom?.id,
    start_date: "2025-01-01",
    status: "active"
  });

  const { data: tuitionPlan } = await supabase
    .from("tuition_plans")
    .insert({
      center_id: center.id,
      child_id: child?.id,
      name: "Full-time Monthly",
      amount_cents: 120000,
      cadence: "monthly",
      effective_date: "2025-01-01"
    })
    .select("id")
    .single();

  const { data: invoice } = await supabase
    .from("invoices")
    .insert({
      center_id: center.id,
      family_id: family.id,
      tuition_plan_id: tuitionPlan?.id,
      issue_date: "2025-02-01",
      due_date: "2025-02-10",
      amount_cents: 120000,
      status: "sent"
    })
    .select("id")
    .single();

  const { data: notice } = await supabase
    .from("notices")
    .insert({
      center_id: center.id,
      title: "February Schedule",
      body: "Reminder: Center is closed Presidents Day.",
      published_at: new Date().toISOString(),
      created_by: adminUser.id
    })
    .select("id")
    .single();

  await supabase.from("notice_recipients").insert({
    center_id: center.id,
    notice_id: notice?.id,
    family_id: family.id,
    child_id: child?.id,
    guardian_id: guardian?.id
  });

  await supabase.from("signature_requests").insert({
    center_id: center.id,
    child_id: child?.id,
    family_id: family.id,
    title: "Permission Slip: Field Trip",
    document_url: "https://example.com/forms/field-trip",
    due_date: "2025-03-01",
    status: "pending",
    created_by: adminUser.id
  });

  await supabase.from("email_templates").upsert({
    center_id: center.id,
    key: "invoice_reminder",
    subject: "CenterHub tuition reminder",
    html_body: "<p>Your tuition invoice is due soon.</p>"
  });

  console.log("Seed complete", {
    centerId: center.id,
    adminUserId: adminUser.id,
    teacherUserId: teacherUser.id,
    parentUserId: parentUser.id,
    invoiceId: invoice?.id
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
