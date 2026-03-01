const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

const TURNSTILE_VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

interface TurnstileRequest {
  token?: string;
  action?: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    const secret = Deno.env.get('TURNSTILE_SECRET_KEY');
    if (!secret) {
      return jsonResponse(
        { success: false, code: 'server_misconfigured', message: 'Verification is temporarily unavailable.' },
        500
      );
    }

    const { token, action }: TurnstileRequest = await req.json();
    if (!token) {
      return jsonResponse(
        { success: false, code: 'missing_token', message: 'Verification failed. Please try again.' },
        400
      );
    }

    const formData = new URLSearchParams();
    formData.append('secret', secret);
    formData.append('response', token);

    const forwardedFor = req.headers.get('x-forwarded-for');
    const remoteIp = forwardedFor?.split(',')[0]?.trim();
    if (remoteIp) {
      formData.append('remoteip', remoteIp);
    }

    const verifyResponse = await fetch(TURNSTILE_VERIFY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: formData
    });

    if (!verifyResponse.ok) {
      return jsonResponse(
        { success: false, code: 'verification_unavailable', message: 'Verification is temporarily unavailable.' },
        502
      );
    }

    const verifyData = await verifyResponse.json();
    const expectedHostname = Deno.env.get('TURNSTILE_EXPECTED_HOSTNAME');

    const hostnameIsValid = !expectedHostname || verifyData.hostname === expectedHostname;
    const actionIsValid = !action || verifyData.action === action;

    if (verifyData.success !== true || !hostnameIsValid || !actionIsValid) {
      return jsonResponse(
        { success: false, code: 'invalid_turnstile', message: 'Verification failed. Please refresh and try again.' },
        400
      );
    }

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('Turnstile verification function error:', error);
    return jsonResponse(
      { success: false, code: 'unexpected_error', message: 'Verification is temporarily unavailable.' },
      500
    );
  }
});

function jsonResponse(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json'
    }
  });
}
