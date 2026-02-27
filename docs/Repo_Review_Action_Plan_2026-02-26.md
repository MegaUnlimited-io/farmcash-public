# FarmCash Public Repo Review + Action Plan

Date: 2026-02-26  
Updated with founder feedback: 2026-02-26  
Updated with new bug-priority feedback: 2026-02-26  
Reviewer: Codex

## Status snapshot (execution tracking)

- ✅ Phase 0 — Shared auth contract: **Completed**
- ✅ Phase 1 — Documentation correction: **Completed**
- 🚧 Phase 1.5 — Core reward/auth bug stabilization: **In progress**

## 1) Repository understanding (concise)

This repo is the production web surface for:
1. Marketing homepage.
2. Waitlist + referral signup funnel.
3. Supabase-auth verification flow and referral dashboard.

Core runtime files:
- `index.html`
- `verify/index.html`
- `referral/index.html`
- `js/farmcash-auth.js`

Shared backend context:
- Supabase DB/Auth is shared by **3 systems**: web app, mobile app, and OCG.
- Mobile + web are the critical auth consumers; OCG is important but mostly RPC/table driven.

---

## 2) Confirmed priorities from your feedback

- ✅ Start immediately on **Phase 0** and keep it short.
- ✅ Proceed immediately on **Phase 1** docs cleanup.
- ✅ Reprioritize: fix reward/auth correctness bugs before Phase 2 hardening.
- ✅ Improve **Phase 3 fingerprint robustness** beyond IP-only dependence.
- ✅ Investigate **Phase 4 bug**: mobile-created users can hit web verify/referral but fail “user not found”.

Operational constraints confirmed:
- Keep costs near-zero; acceptable if using existing Supabase (Edge Functions / existing infra).
- Production-first links are fine for now.
- Prefer practical recommendations with low process overhead.

---


## 2.1) New critical bug backlog (added)

1. **Seed crediting regression (new users not receiving signup + verification seeds).**
   - Symptom: first-time users complete signup/email verification but do not receive expected seed awards.
   - Suspected area: backend migration/function drift (possible MIGRATION008 side effects).
   - Scope impact: web onboarding economics and referral funnel reliability.

2. **Mobile -> web handoff user-not-found bug (existing known bug).**
   - Symptom: mobile-created user can follow Supabase email links to web, but referral/dashboard path fails with user-not-found behavior.
   - Suspected area: auth/profile parity (`auth.users` exists while `public.users` row missing or inaccessible).

3. **Signup email template mismatch for app-created users (new UX bug).**
   - Symptom: first-time app signup emails use Supabase "confirm email change" language, which is confusing for account creation.
   - Expected: a dedicated signup verification template/message that clearly says "verify your email to complete your account".

4. **Farm plot lock-state flash on initial load (new UX bug).**
   - Symptom: newly loaded farm briefly shows locked-plot icons before rendering actual unlocked/current state.
   - Expected: first rendered frame should reflect true lock/unlock state without transient incorrect flash.

## 3) Updated action plan

## Phase 0 — Shared auth contract (completed)
Goal: prevent web/mobile regressions while moving fast.

Deliverable (short doc to add to `/docs/`):
- Minimal “Do Not Break” contract for shared auth/data:
  - `auth.users.id` ↔ `public.users.id` assumptions
  - required user profile fields for web + mobile
  - referral fields/flags used in both systems
  - expected behavior when user exists in auth but not yet in public.users

Implementation note:
- Keep this to 1 page max, checklist style.

## Phase 1 — Documentation correction (completed)
Goal: make docs trustworthy before deeper changes.

Tasks:
1. Reconcile `docs/FarmCash_web_application.md` with `docs/FarmCash_Complete_Public_Schema_v3.md`.
2. Replace outdated column names (`user_level`, `experience_points` → `level`, `xp`).
3. Resolve RLS status inconsistencies.
4. Standardize referral code format references (6 vs 8 chars) based on current DB truth.
5. Add a short “Cross-system impact (web/mobile/OCG)” callout section in backend-affecting docs.

## Phase 1.5 — Core reward/auth bug stabilization (active)
Goal: restore correctness before adding security hardening layers.

Tasks:
1. Reproduce seed crediting regression end-to-end (signup -> verify -> expected +150 seeds).
2. Diff bonus/reward SQL functions and triggers against last known-good behavior:
   - `process_email_verification()`
   - `award_signup_bonus()`
   - `award_verification_bonus()`
   - `record_seed_transaction()`
3. Validate config keys/defaults used by bonus functions after migration changes.
4. Validate guard flags and idempotency logic:
   - `waitlist_bonus_claimed`
   - `email_verified_bonus_claimed`
5. Fix mobile->web user-not-found handoff bug in same stabilization pass (shared auth/profile contract).

Exit criteria:
- New web user gets expected signup + verification seeds again.
- Mobile-created user can complete verify/login and load web dashboard without user-not-found failures.

Immediate execution checklist (current pass):
1. Reproduce and capture baseline logs for seed-credit regression paths.
2. Diff and patch verification/signup award function behavior.
3. Validate idempotency flags on real flows (web-created + mobile-created users).
4. Re-run cross-platform verify/login/dashboard smoke path after fixes.

## Phase 2 — Security hardening before traffic (high priority)
Goal: raise bot resistance without new monthly infra.

Tasks:
1. Add Supabase Edge Function for **server-side Turnstile verification**.
2. Require successful Turnstile verification before allowing waitlist creation flow.
3. Remove token-adjacent debug logs from verify flow.
4. Add security checklist for production:
   - debug logs off
   - auth callback sanity checks
   - failure-mode UX that does not leak sensitive details.

Cost posture:
- Use existing Supabase account only (no separate server spend).

## Phase 3 — Fingerprint quality improvements (high value)
Goal: reduce easy evasion from IP resets and improve fraud signal quality.

Tasks:
1. Fix OS detection order bug (`Android` check before `Linux`).
2. Add extra low-cost fingerprint inputs:
   - browser major version
   - OS version when available from UA parsing
   - platform/device memory/concurrency signals when available
3. Keep IP as one signal, not the primary identifier.
4. Version the fingerprint payload (`fp_version`) so schema/rules can evolve safely.

Target fingerprint approach:
- `stable_fingerprint = hash(non-IP traits)`
- `network_fingerprint = hash(IP + non-IP traits)`
- Store both for fraud analysis and dedupe confidence scoring.

## Phase 4 — Cross-platform auth regression + known bug investigation
Goal: catch and fix shared auth edge cases now.

Known bug to investigate first:
- Mobile signup succeeds, user clicks Supabase email link, web redirect works, but referral dashboard says user not found.

Likely root-cause classes:
1. User exists in `auth.users` but missing in `public.users`.
2. Profile creation race/timing issue between signup and verification.
3. RLS/policy mismatch blocking expected read path.
4. Assumptions in web dashboard query path that do not hold for mobile-created users.

Regression checklist (web + mobile):
1. Mobile signup → email verify → web referral load.
2. Web signup → verify → referral load.
3. Magic-link login from both origins.
4. Referral attribution + idempotent bonus behavior.

---

## 4) Recommended execution order (updated)

1. Phase 0 (shared contract) + Phase 1 (docs fix) [done].
2. **Phase 1.5 (core reward/auth bug stabilization) — do next.**
3. Phase 2 (Turnstile server validation + verify log cleanup).
4. Phase 4 (cross-platform regression checklist; keep running as a release gate).
5. Phase 3 (fingerprint enhancement rollout).

Rationale:
- You are correct: hardening a non-100% working system is suboptimal. Correctness for rewards/auth should be restored first, then abuse hardening.

---

## 5) Concrete recommendation on “compatibility window vs lockstep”

Given current stage (pre-live users, production-first workflow), use:
- **Lightweight compatibility window** for backend-breaking changes:
  - Keep old + new fields/behaviors for a short fixed window (e.g., 7 days), then remove.
  - Announce changes in a tiny changelog doc.

Why this is the best fit now:
- Less process overhead than strict lockstep releases.
- Lower risk of breaking mobile unexpectedly.
- Minimal cost and minimal slowdown.
