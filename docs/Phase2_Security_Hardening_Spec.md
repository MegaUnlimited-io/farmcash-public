# Phase 2 Kickoff Spec — Security Hardening Before Traffic

1. **Goal (1 sentence):** Ensure only server-verified human signups can create waitlist accounts while keeping verify/login flows safe and minimally verbose.

2. **Scope:**
- Allowed to change:
  - `index.html` (Turnstile token collection + submit flow wiring)
  - `js/farmcash-auth.js` (API call integration helpers if needed)
  - `verify/index.html` (remove token-adjacent debug logs, tighten callback handling)
  - `supabase/functions/*` (new server-side Turnstile verification function)
  - `docs/*` security checklist/runbook updates
- Systems in scope:
  - FarmCash web app
  - Existing Supabase project (Edge Functions + existing DB/RLS)

3. **Non-goals:**
- No redesign/polish of onboarding UI.
- No referral economy/schema changes.
- No mobile app code changes.
- No new paid third-party infra/services.

4. **Acceptance criteria:**
- Signup/waitlist creation is blocked unless Turnstile token is verified server-side.
- Invalid/expired/missing Turnstile token returns a user-safe error and does not create waitlist/user side effects.
- Valid token allows normal signup path and preserves existing referral attribution behavior.
- Verify page no longer logs token-adjacent sensitive details in production paths.
- Security checklist doc exists and includes: debug logs off, auth callback sanity checks, and non-sensitive failure UX.

5. **Test plan:**
- Commands:
  - `supabase functions serve` (local edge function smoke validation)
  - `supabase functions deploy <turnstile-verify-function>`
  - `rg -n "access_token|refresh_token|token" verify/index.html js/farmcash-auth.js`
- Manual QA path:
  1. Attempt signup with missing/invalid token → blocked, no waitlist record created.
  2. Complete signup with valid token → waitlist/user records created normally.
  3. Verify email link and dashboard load still work.
  4. Referral signup path still records `referred_by` as expected.

6. **Output format:**
- PR must include:
  - concise summary of changes
  - risk section (security + rollout risk)
  - follow-up section (Phase 3 dependencies / hardening leftovers)
