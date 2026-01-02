exports.handler = async (event, context) => {
  const { token, type } = JSON.parse(event.body);
  
  const response = await fetch(`${process.env.SUPABASE_URL}/auth/v1/verify`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': process.env.sb_publishable_ZNm9BWAUZkAV29iYMkOlHg_gIc6NVGM // Server-side only
    },
    body: JSON.stringify({ token, type })
  });

  return {
    statusCode: response.status,
    body: JSON.stringify({ success: response.ok })
  };
};