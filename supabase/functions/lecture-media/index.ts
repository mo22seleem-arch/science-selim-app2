// deploy: supabase functions deploy lecture-media
// secrets: supabase secrets set BUNNY_CDN_HOST=vz-xxxx.b-cdn.net BUNNY_TOKEN_KEY=<Token Authentication Key>
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type, apikey' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

async function bunnyDirectoryUrl(videoId: string, ttlSec: number) {
  const host = Deno.env.get('BUNNY_CDN_HOST')!, key = Deno.env.get('BUNNY_TOKEN_KEY')!;
  const dir = `/${videoId}/`, expires = Math.floor(Date.now() / 1000) + ttlSec;
  // Bunny "Basic" token auth, directory token: SHA256(key + token_path + expires + "token_path=" + token_path)
  const base = `${key}${dir}${expires}token_path=${dir}`;
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(base));
  const token = btoa(String.fromCharCode(...new Uint8Array(d))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  // path-based form: segments inherit the token automatically (required for HLS)
  return `https://${host}/bcdn_token=${token}&expires=${expires}&token_path=${encodeURIComponent(dir)}${dir}playlist.m3u8`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const auth = req.headers.get('Authorization');
    if (!auth) return json({ error: 'unauthorized' }, 401);
    const { lecture_id, kind, device_id } = await req.json();

    const user = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } });
    const { data: me } = await user.auth.getUser();
    if (!me?.user) return json({ error: 'unauthorized' }, 401);

    // 1) this request must come from the student's ACTIVE device (a stolen token on another phone is useless)
    const { data: prof } = await user.from('profiles').select('active_device_id,is_banned,integrity_ok_until').eq('id', me.user.id).single();
    if (!prof || prof.is_banned || prof.active_device_id !== device_id) return json({ error: 'device_mismatch' }, 403);

    // 1b) optional Play Integrity gate (set INTEGRITY_ENFORCE=true once the app is on Google Play)
    if (Deno.env.get('INTEGRITY_ENFORCE') === 'true' && !(prof.integrity_ok_until && new Date(prof.integrity_ok_until) > new Date()))
      return json({ error: 'integrity_required' }, 403);

    // 2) entitlement (free / enrolled / staff) evaluated by the database
    const { data: ok } = await user.rpc('lecture_access', { p_lecture: lecture_id });
    if (ok !== true) return json({ error: 'locked' }, 403);

    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: lec } = await admin.from('lectures').select('video_provider,video_ref,pdf_path').eq('id', lecture_id).single();
    if (!lec) return json({ error: 'not_found' }, 404);

    if (kind === 'pdf') {
      if (!lec.pdf_path) return json({ error: 'no_pdf' }, 404);
      const { data, error } = await admin.storage.from('lecture-pdfs').createSignedUrl(lec.pdf_path, 90); // 90 s only
      if (error) return json({ error: 'sign_failed' }, 500);
      return json({ url: data.signedUrl });
    }
    if (!lec.video_ref) return json({ error: 'no_video' }, 404);
    if (lec.video_provider === 'bunny') return json({ url: await bunnyDirectoryUrl(lec.video_ref, 4 * 3600) });
    if (lec.video_provider === 'hls') return json({ url: lec.video_ref });
    return json({ error: 'unsupported_provider' }, 400);
  } catch (_) { return json({ error: 'server_error' }, 500); }
});
