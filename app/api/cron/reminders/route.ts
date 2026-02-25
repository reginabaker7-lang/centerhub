import { createClient } from "@supabase/supabase-js";
import { Resend } from "resend";
import { getRequiredEnv } from "@/lib/env";

export const dynamic = "force-dynamic";

type InvoiceReminder = {
  id: string;
  center_id: string;
  family_id: string;
  due_date: string;
  amount_cents: number;
  status: string;
  centers: { name: string } | null;
  families: { name: string } | null;
};

function buildReminderEmail(invoice: InvoiceReminder, appBaseUrl: string): { subject: string; html: string } {
  const dueDate = new Date(invoice.due_date).toLocaleDateString();
  const amount = (invoice.amount_cents / 100).toLocaleString("en-US", {
    style: "currency",
    currency: "USD"
  });
  const statusLabel = invoice.status === "overdue" ? "overdue" : "due soon";

  return {
    subject: `CenterHub Tuition Reminder: ${statusLabel.toUpperCase()}`,
    html: `
      <p>Hello ${invoice.families?.name ?? "Family"},</p>
      <p>This is a reminder from ${invoice.centers?.name ?? "your center"} that your invoice is <strong>${statusLabel}</strong>.</p>
      <ul>
        <li><strong>Amount:</strong> ${amount}</li>
        <li><strong>Due date:</strong> ${dueDate}</li>
      </ul>
      <p>Please log in to review details and submit payment.</p>
      <p><a href="${appBaseUrl}">Open CenterHub</a></p>
    `
  };
}

export async function GET() {
  const supabaseUrl = getRequiredEnv("NEXT_PUBLIC_SUPABASE_URL");
  const serviceRoleKey = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const resendApiKey = getRequiredEnv("RESEND_API_KEY");
  const emailFrom = getRequiredEnv("EMAIL_FROM");
  const appBaseUrl = getRequiredEnv("APP_BASE_URL");

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const resend = new Resend(resendApiKey);

  const today = new Date();
  const dueSoonCutoff = new Date(today);
  dueSoonCutoff.setDate(today.getDate() + 3);

  const { data: invoices, error: invoiceError } = await supabase
    .from("invoices")
    .select("id, center_id, family_id, due_date, amount_cents, status, centers(name), families(name)")
    .in("status", ["sent", "overdue"])
    .lte("due_date", dueSoonCutoff.toISOString().slice(0, 10));

  if (invoiceError) {
    return Response.json({ success: false, error: invoiceError.message }, { status: 500 });
  }

  const reminders = (invoices ?? []) as InvoiceReminder[];

  if (!reminders.length) {
    return Response.json({ success: true, scanned: 0, sent: 0, logged: 0 });
  }

  const recipientQuery = await supabase
    .from("guardians")
    .select("id, family_id, full_name, email")
    .not("email", "is", null);

  if (recipientQuery.error) {
    return Response.json({ success: false, error: recipientQuery.error.message }, { status: 500 });
  }

  const recipientsByFamily = new Map<string, { id: string; full_name: string; email: string }[]>();

  for (const guardian of recipientQuery.data ?? []) {
    const group = recipientsByFamily.get(guardian.family_id) ?? [];
    group.push({
      id: guardian.id,
      full_name: guardian.full_name,
      email: guardian.email as string
    });
    recipientsByFamily.set(guardian.family_id, group);
  }

  let sent = 0;
  let logged = 0;

  for (const invoice of reminders) {
    const recipients = recipientsByFamily.get(invoice.family_id) ?? [];
    const template = buildReminderEmail(invoice, appBaseUrl);

    for (const recipient of recipients) {
      const emailResult = await resend.emails.send({
        from: emailFrom,
        to: recipient.email,
        subject: template.subject,
        html: template.html
      });

      const status = emailResult.error ? "failed" : "sent";
      const providerId = emailResult.data?.id ?? null;

      if (!emailResult.error) {
        sent += 1;
      }

      const { error: logError } = await supabase.from("email_logs").insert({
        center_id: invoice.center_id,
        to_email: recipient.email,
        subject: template.subject,
        template_key: "invoice_reminder",
        provider_message_id: providerId,
        status,
        metadata: {
          invoice_id: invoice.id,
          guardian_id: recipient.id,
          recipient_name: recipient.full_name
        }
      });

      if (!logError) {
        logged += 1;
      }
    }
  }

  return Response.json({ success: true, scanned: reminders.length, sent, logged });
}
