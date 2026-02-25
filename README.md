# CenterHub

CenterHub helps childcare programs manage families, classrooms, billing, notices, and signatures.

This guide is written for first-time setup and assumes you are starting from scratch.

## 1) Create a Supabase project

1. Go to [https://supabase.com](https://supabase.com) and sign in.
2. Click **New project**.
3. Choose your organization.
4. Enter:
   - **Project name** (example: `centerhub-prod`)
   - **Database password** (save this securely)
   - **Region** closest to your users
5. Click **Create new project** and wait for provisioning.

## 2) Find Supabase URL and API keys

In Supabase, open your project and go to **Project Settings → API**.

You need these values:

- **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
- **anon public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- **service_role secret key** → `SUPABASE_SERVICE_ROLE_KEY` (server-only, never expose to browsers)

## 3) Configure Auth (email/password)

1. In Supabase go to **Authentication → Providers**.
2. Make sure **Email** provider is enabled.
3. Turn on **Email + Password** sign-ins.
4. (Optional) Disable email confirmations in development if you want quick test accounts.
5. Save settings.

## 4) Set environment variables

1. Copy `.env.example` to `.env.local`:

```bash
cp .env.example .env.local
```

2. Fill in all values:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY`
- `EMAIL_FROM` (example: `CenterHub <noreply@yourdomain.com>`)
- `APP_BASE_URL` (example: `http://localhost:3000` locally)

## 5) Run migrations in Supabase (SQL files)

Use the SQL editor in Supabase:

1. Open **SQL Editor → New query**.
2. Paste the contents of `supabase/migrations/001_init.sql`.
3. Run the query.
4. Confirm tables exist in **Table Editor**.

This migration creates all required entities (centers, profiles, families, guardians, children, classrooms, billing, notices, signatures, templates, and email logs), indexes, triggers, RLS, and role-based policies.

## 6) Seed sample data

1. Install dependencies:

```bash
npm install
```

2. Run the seed script:

```bash
npm run seed
```

The seed script creates:

- 1 center
- 1 admin user
- 1 teacher user
- 1 parent user
- sample family, guardian, child, classroom, enrollment, tuition plan, invoice, notice, and signature request

## 7) Run locally

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## 8) Build check

```bash
npm run build
```

## 9) Deploy to Vercel

1. Push this repo to GitHub.
2. Go to [https://vercel.com](https://vercel.com) and import the repo.
3. In project settings, add all environment variables from `.env.local`.
4. Deploy.

## 10) Configure daily reminders cron on Vercel

CenterHub exposes a cron route at:

- `GET /api/cron/reminders`

It checks invoices due soon/overdue, sends reminder emails via Resend, and writes records to `email_logs`.

### Add Vercel Cron

1. In Vercel project settings, go to **Cron Jobs**.
2. Add a job:
   - **Path:** `/api/cron/reminders`
   - **Schedule:** `0 13 * * *` (daily at 13:00 UTC; adjust as needed)
3. Save.

### Optional `vercel.json` example

```json
{
  "crons": [
    {
      "path": "/api/cron/reminders",
      "schedule": "0 13 * * *"
    }
  ]
}
```

---

## File checklist included in this repo

- `.env.example`
- `supabase/migrations/001_init.sql`
- `scripts/seed.ts`
- `app/api/cron/reminders/route.ts`

