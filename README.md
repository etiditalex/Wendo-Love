# Wendo Love (Upendo Pamoja)

Love. Dignity. Connection.

Privacy-first matchmaking for adults 18 and over: people living with HIV, and HIV-negative adults who choose a respectful relationship across HIV status. Kenya-first.

The product is not a clinic, a testing service, or a patient registry. It does not collect clinic names, patient numbers, or treatment cards.

## Layout

| Path | What it is |
| --- | --- |
| `apps/web` | Next.js site and member screens |
| `apps/mobile` | Flutter app for Android, iOS, and a Windows shell for local preview |
| `supabase` | Postgres schema, row-level security, and local config |
| `shared/domain.json` | Shared labels: relationship intent, optional status values, report reasons |

## Privacy shape

- Date of birth lives in `private_identity`. Discovery returns an age, not the date.
- Optional HIV status lives in `health_profiles`. Only the owner can read that table.
- Sharing with another member is a separate, explicit `health_shares` row, and only with a mutual match.
- Matching uses stated preferences. Status is not a column on the discovery card.
- Profile photos go in a private Storage bucket, under a folder named with the member's id.
- Blur-until-mutual is a member setting (`profiles.blur_until_mutual`), off by default for this pilot.
- Photo verify uploads wait for staff approval (`photo_verify_requested_at` → `approve_photo_verify`).

## Built in this pilot

- Email/password join and login (web + mobile), same Supabase project
- Profile, photos, likes, pass, favorites, views, matches, chat
- Block and report (member + staff moderation queue)
- Trusted contacts, meeting check-ins, optional Jitsi video link
- Partner resources and Wendo Plus interest (no billing)
- Account export (`export_own_account`), pause, delete flows
- Discreet local phone alerts while the app process is alive
- Device push token table + local device-id registration path (FCM/APNs not wired yet)

## Still out of scope / next

- Auth beyond email/password (phone, passkey, MFA, Google)
- iOS App Store / Google Play readiness and store listings
- Kiswahili / localization foundation
- Remote push when the app is killed (FCM/APNs + edge worker)
- Live payments for premium

## Web

```powershell
cd apps/web
copy .env.example .env.local
npm run dev
```

Put the Supabase project URL and anon key in `.env.local`. Do not put the service role key in the web or mobile app.

Open http://localhost:3000. Member screens are under `/app`.

## Vercel

The Next.js app is in **`apps/web`**, not the repo root. Deploying the repo root alone often shows Vercel’s `404 NOT_FOUND` page.

**Required:** Project → **Settings → General → Root Directory** → `apps/web` → Save → Redeploy.

Also set Production env vars:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

Framework Preset: Next.js. Leave Build/Output as defaults after Root Directory is `apps/web`.

## Mobile

Flutter is not on the system PATH yet. This machine has the SDK at `%LOCALAPPDATA%\flutter`. Windows plugin builds need Developer Mode so Flutter can create symlinks (`start ms-settings:developers`).

```powershell
$env:Path = "$env:LOCALAPPDATA\flutter\bin;" + $env:Path
cd apps/mobile
flutter pub get
flutter run -d windows
```

Pass the same public keys when you are ready to sign in:

```powershell
flutter run -d windows --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Backend

Install the [Supabase CLI](https://supabase.com/docs/guides/cli) and Docker, then from the repository root:

```powershell
supabase start
supabase db reset
```

`supabase db reset` applies `supabase/migrations`, including `20261103160000_pilot_gaps.sql` (push tokens, check-ins, partners, premium interest, staff moderation, export). Hosted projects use `supabase link` and `supabase db push` after the legal and data-protection review, not before you mean to store real member data.

Staff moderation: insert a row into `staff_roles` (`user_id`, `role` = `moderator` or `admin`) for the reviewer account.
