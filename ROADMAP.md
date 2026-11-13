# Roadmap
1. **Phase 1** Theme, RTL, triple-name + Egyptian phone auth, single-device lock, FLAG_SECURE, full DB schema + RLS.
1.5 SMS OTP for *verified* phones (Twilio/Vonage via Supabase Phone auth or an Edge Function).
2. Course/Unit/Lecture browsing, free-vs-locked UI, "enter activation code" sheet -> `redeem_code`.
3. Protected player (HLS/Bunny signed URLs or VdoCipher OTP from an Edge Function) + moving watermark (name + phone).
4. In-app PDF viewer (signed URL, bytes in memory, no share/download) + quiz screens -> `submit_quiz`.
5. Admin dashboard: content CRUD, quiz builder, code batches (+CSV export), sub-admin permissions, session monitor, device reset.
6. Hardening: Play Integrity, root/emulator detection, obfuscation (`--obfuscate`), rate-limit redeem, audit log, release signing.

# Setup
1. Supabase -> Auth -> Providers -> Email: enable, **disable "Confirm email"**. SQL editor: run `supabase/schema.sql`.
2. Database -> Replication: enable Realtime on `profiles`.
3. `flutter create . --org com.selim --project-name science_selim` (keeps these files), then in
   `android/app/build.gradle` set `minSdkVersion 23` and make sure `MainActivity.kt` is the one in this repo.
4. `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
5. **Immediately register 01091277447 yourself** (see warning in chat) before publishing the app.

# Phase 3+4 setup
1. Run `supabase/phase3.sql`.
2. `supabase functions deploy lecture-media` then
   `supabase secrets set BUNNY_CDN_HOST=vz-xxxx.b-cdn.net BUNNY_TOKEN_KEY=<Token Authentication Key>`.
3. Bunny: Stream library's pull zone -> Security -> enable Token Authentication (+ "Directory token"), copy the key.
4. Android: add `<uses-permission android:name="android.permission.INTERNET"/>` to `android/app/src/main/AndroidManifest.xml`
   (flutter create only adds it to debug), and set `minSdkVersion 21`+.
