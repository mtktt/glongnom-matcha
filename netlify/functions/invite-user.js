// Netlify Function — Invite new staff user
// Uses native fetch (Node 18) — no npm dependencies needed
// Env vars required: SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, SITE_URL

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const authHeader = event.headers['authorization'] || '';
  const userToken  = authHeader.replace('Bearer ', '').trim();
  if (!userToken) return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };

  const SUPABASE_URL         = process.env.SUPABASE_URL;
  const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
  const SUPABASE_ANON_KEY    = process.env.SUPABASE_ANON_KEY;
  const SITE_URL             = process.env.SITE_URL || 'https://glongnom-pos.netlify.app';

  try {
    const { email, role, name } = JSON.parse(event.body || '{}');
    if (!email) return { statusCode: 400, body: JSON.stringify({ error: 'Email is required' }) };

    const validRoles = ['admin', 'manager', 'cashier', 'kitchen', 'staff'];
    const assignRole = validRoles.includes(role) ? role : 'staff';

    // 1. Verify the requesting user's session token
    const meRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        'apikey':        SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${userToken}`,
      },
    });
    if (!meRes.ok) return { statusCode: 401, body: JSON.stringify({ error: 'Invalid session' }) };
    const requester = await meRes.json();

    // 2. Check the requester's role in user_profiles
    const profileRes = await fetch(
      `${SUPABASE_URL}/rest/v1/user_profiles?id=eq.${requester.id}&select=role`,
      {
        headers: {
          'apikey':        SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );
    const profiles = await profileRes.json();
    const requesterRole = profiles?.[0]?.role;

    if (!['admin', 'manager'].includes(requesterRole)) {
      return { statusCode: 403, body: JSON.stringify({ error: 'Only admin or manager can invite users' }) };
    }
    if (requesterRole === 'manager' && assignRole === 'admin') {
      return { statusCode: 403, body: JSON.stringify({ error: 'Managers cannot assign admin role' }) };
    }

    // 3. Send invite via Supabase Admin API
    const inviteRes = await fetch(`${SUPABASE_URL}/auth/v1/invite`, {
      method:  'POST',
      headers: {
        'apikey':        SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify({
        email,
        data:        { name: name || email },
        redirect_to: `${SITE_URL}/reset-password.html`,
      }),
    });

    const invited = await inviteRes.json();
    if (!inviteRes.ok) {
      return { statusCode: 400, body: JSON.stringify({ error: invited.msg || invited.message || 'Invite failed' }) };
    }

    // 4. Update role + name in user_profiles (trigger creates the row)
    if (invited?.id) {
      await fetch(
        `${SUPABASE_URL}/rest/v1/user_profiles?id=eq.${invited.id}`,
        {
          method:  'PATCH',
          headers: {
            'apikey':        SUPABASE_SERVICE_KEY,
            'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
            'Content-Type':  'application/json',
            'Prefer':        'return=minimal',
          },
          body: JSON.stringify({ name: name || email, role: assignRole }),
        }
      );
    }

    return { statusCode: 200, body: JSON.stringify({ success: true, email }) };

  } catch (err) {
    console.error('invite-user error:', err);
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
