# FarmCash Web Application Backlog

Date created: 2026-02-27  
Scope: **Web application repository only** (`farmcash-public`).

## Critical (Phase 1.5)

1. **Seed crediting regression for web waitlist signup users**
   - Symptom: web signup + email verify completes, but signup bonus (+100) and verification bonus (+50) transactions are missing.
   - Observed state: `demo_seeds` transaction exists, expected `signup_bonus` / `verification_bonus` records absent.
   - Priority: P0

2. **Mobile->web handoff profile parity edge case**
   - Symptom: auth session is valid but dashboard path previously failed when supporting rows were missing.
   - Status: partially mitigated in web (dashboard now tolerates missing `waitlist_signups` row); continue monitoring cross-platform auth/profile parity.
   - Priority: P1

## Product / UX Improvements (web scope)

1. **Signup verification email wording mismatch**
   - Symptom: some first-time signup emails show "confirm email change" language.
   - Desired: template text should clearly communicate account verification completion for signup.
   - Priority: P2

## Notes
- Non-web tasks (e.g., mobile-only rendering/UX bugs) are intentionally excluded and tracked in the mobile backlog.
- Keep this file as the canonical place for backlog updates going forward.
