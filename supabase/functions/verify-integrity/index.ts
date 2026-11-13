// deploy: supabase functions deploy verify-integrity
// secrets: GOOGLE_SA_JSON (service-account key JSON, Play Integrity API enabled), PLAY_PACKAGE_NAME (e.g. com.selim.science)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type, apikey' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const b64u = (b: ArrayBuffer | Uint8Array) => btoa(String.fromCharCode(...new Uint8Array(b as ArrayBuffer))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

async function googleAccessToken(sa: { client_email: string; private_key: string }) {
  const enc = (o: unknown) => b64u(new TextEncoder().encode(JSON.stringify(o)));
  const iat = Math.floor(Date.now() / 1000);
  const unsigned = `${enc({ alg: 'RS256', typ: 'JWT' })}.${enc({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/playintegrity',
    aud: 'https://oauth2.googleapis.com/token', iat, exp: iat + 3000 })}`;
  const der = Uint8Array.from(atob(sa.private_key.replace(/-----[A-Z ]+-----|\s/g, '')), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${b64u(sig)}` }) });
  return (await r.json()).access_token as string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const auth = req.headers.get('Authorization'); if (!auth) return json({ error: 'unauthorized' }, 401);
    const user = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } });
    const { data: me } = await user.auth.getUser(); if (!me?.user) return json({ error: 'unauthorized' }, 401);
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const body = await req.json();

    if (body.action === 'nonce') {                                   // step 1: server-issued nonce (anti-replay)
      const nonce = b64u(crypto.getRandomValues(new Uint8Array(32)));
      await admin.from('integrity_nonces').upsert({ user_id: me.user.id, nonce, created_at: new Date().toISOString() });
      return json({ nonce });
    }

    if (body.action === 'verify') {                                  // step 2: Google decodes the token, we check the verdicts
      const { data: n } = await admin.from('integrity_nonces').select('*').eq('user_id', me.user.id).single();
      await admin.from('integrity_nonces').delete().eq('user_id', me.user.id);          // single use
      if (!n || Date.now() - new Date(n.created_at).getTime() > 5 * 60_000) return json({ ok: false, reason: 'nonce_expired' });

      const pkg = Deno.env.get('PLAY_PACKAGE_NAME')!;
      const at = await googleAccessToken(JSON.parse(Deno.env.get('GOOGLE_SA_JSON')!));
      const r = await fetch(`https://playintegrity.googleapis.com/v1/${pkg}:decodeIntegrityToken`, {
        method: 'POST', headers: { Authorization: `Bearer ${at}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ integrity_token: body.token }) });
      const p = (await r.json()).tokenPayloadExternal;
      const okAll = p
        && p.requestDetails?.requestPackageName === pkg
        && p.requestDetails?.nonce === n.nonce
        && Math.abs(Date.now() - Number(p.requestDetails?.timestampMillis)) < 5 * 60_000
        && p.appIntegrity?.appRecognitionVerdict === 'PLAY_RECOGNIZED'                 // genuine, unmodified build from Play
        && (p.deviceIntegrity?.deviceRecognitionVerdict ?? []).includes('MEETS_DEVICE_INTEGRITY'); // real, non-rooted-ish device
      if (!okAll) { await admin.from('profiles').update({ integrity_ok_until: null }).eq('id', me.user.id); return json({ ok: false }); }
      await admin.from('profiles').update({ integrity_ok_until: new Date(Date.now() + 12 * 3600_000).toISOString() }).eq('id', me.user.id);
      return json({ ok: true });
    }
    return json({ error: 'bad_action' }, 400);
  } catch (_) { return json({ ok: false, error: 'server_error' }, 500); }
});
