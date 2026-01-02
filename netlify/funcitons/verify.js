exports.handler = async (event, context) => {
  const { token, type } = JSON.parse(event.body);
  
  const response = await fetch(`${process.env.SUPABASE_URL}/auth/v1/verify`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': process.env.SUPABASE_ANON_KEY // Server-side only
    },
    body: JSON.stringify({ token, type })
  });

  return {
    statusCode: response.status,
    body: JSON.stringify({ success: response.ok })
  };
};