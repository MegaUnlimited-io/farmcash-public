# Phase 2 Security Hardening Checklist

Use this checklist before enabling production traffic for waitlist/signup flows.

## 1) Turnstile server verification gate

- [ ] `TURNSTILE_SECRET_KEY` is set in Supabase Edge Function secrets.
- [ ] Optional: `TURNSTILE_EXPECTED_HOSTNAME` is set to the production hostname.
- [ ] `turnstile-verify` function is deployed.
- [ ] `supabase/functions/turnstile-verify/config.toml` sets `verify_jwt = false` so pre-auth signup users can call the function.
- [ ] Cloudflare PAT `401` console lines are treated as expected browser-level Turnstile behavior unless server verification also fails.
- [ ] Signup flow calls server-side verification before creating auth/waitlist side effects.
- [ ] Missing/invalid/expired Turnstile tokens return a non-sensitive user error.

## 2) Verify callback safety checks

- [ ] Verify page requires both `access_token` and `refresh_token` before `setSession`.
- [ ] Callback logic only treats explicit `type=login|magiclink` links as login callbacks.
- [ ] Non-login verification links continue through email verification bonus path safely.

## 3) Production logging and UX hygiene

- [ ] Token-adjacent debug logging is disabled for verify callback paths.
- [ ] Non-sensitive failure UX is shown to users (no secret/token internals exposed).
- [ ] Error states still provide recovery action (e.g., back to login).

## 4) Runbook commands

```bash
# Local smoke test for edge function
supabase functions serve turnstile-verify

# Deploy verification function
supabase functions deploy turnstile-verify

# Quick scan for token logging regressions
rg -n "access_token|refresh_token|token" verify/index.html js/farmcash-auth.js
```

## 5) Manual QA

1. Attempt signup with no Turnstile token (or invalid token) and confirm signup is blocked with no account/waitlist side effects.
2. Complete signup with a valid Turnstile token and confirm normal account + waitlist creation.
3. Complete email verify link flow and confirm redirect to dashboard still works.
4. Complete referral signup path and confirm `referred_by` is still stored.

## 6) Fast local pre-merge checks (recommended)

```bash
# Catch inline script syntax regressions before deploy
./scripts/validate_frontend_syntax.sh

# Optional UI smoke check for submit handler no-refresh behavior
python -m http.server 4173
```

For full end-to-end Turnstile verification locally, you need:
- a Turnstile site key that allows `localhost`
- Supabase function deployed with `verify_jwt = false`
- valid `TURNSTILE_SECRET_KEY` in function secrets
