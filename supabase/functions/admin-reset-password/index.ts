// deploy: supabase functions deploy admin-reset-password
// Owner-only: sets a new password for a student and signs them out everywhere.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type, apikey' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const auth = req.headers.get('Authorization'); if (!auth) return json({ error: 'unauthorized' }, 401);
    const user = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } });
    const { data: me } = await user.auth.getUser(); if (!me?.user) return json({ error: 'unauthorized' }, 401);

    const { data: isSuper } = await user.rpc('is_super');          // evaluated by the database from the caller's JWT
    if (isSuper !== true) return json({ error: 'forbidden' }, 403);

    const { user_id, password } = await req.json();
    if (typeof user_id !== 'string' || typeof password !== 'string' || password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password))
      return json({ error: 'bad_password' }, 400);

    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: target } = await admin.from('profiles').select('role').eq('id', user_id).single();
    if (!target) return json({ error: 'not_found' }, 404);
    if (target.role === 'super_admin') return json({ error: 'owner_protected' }, 403);   // owner changes own password inside the app

    const { error } = await admin.auth.admin.updateUserById(user_id, { password });
    if (error) return json({ error: 'update_failed' }, 500);

    await user.rpc('admin_reset_device', { p_user: user_id });      // kills old sessions + unbinds device (audited)
    await admin.from('audit_log').insert({ actor: me.user.id, actor_name: 'owner', action: 'student.password_reset', target: user_id });
    return json({ ok: true });
  } catch (_) { return json({ error: 'server_error' }, 500); }
});
