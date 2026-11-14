# دليل التشغيل الكامل — العلوم مع محمد سليم

## الترتيب الصحيح (مرة واحدة)
1. **Supabase**
   1. Auth → Providers → Email: فعّله، و**أطفئ "Confirm email"**. Auth → Policies: الحد الأدنى لكلمة المرور 8.
   2. SQL Editor → الصق كل `supabase/full_setup.sql` → Run.
   3. نشر الدوال (مطلوب فقط للفيديو/PDF/كلمة المرور):
      ```
      supabase functions deploy lecture-media
      supabase functions deploy admin-reset-password
      supabase functions deploy verify-integrity        # اختياري (Play Integrity)
      supabase secrets set BUNNY_CDN_HOST=vz-xxxx.b-cdn.net BUNNY_TOKEN_KEY=<مفتاح Bunny>
      ```
2. **Codemagic**: Environment variables → Group `supabase` → `SUPABASE_URL` و `SUPABASE_ANON_KEY`، ثم شغّل `Android Debug APK`.
3. **أول تسجيل في التطبيق = رقم المالك `01091277447`** (النظام يرفض تسجيل أي طالب قبل المالك).
4. من لوحة التحكم: أضف كورساً في مرحلة، ثم وحدة، ثم محاضرة، ثم ولّد كوداً، وجرّب التفعيل بحساب طالب.

## مشاكل متوقعة وحلولها
| المشكلة | الحل |
|---|---|
| الطالب نسي كلمة المرور | لوحة التحكم → المشرفون والطلاب → أيقونة الطالب → "تعيين كلمة مرور جديدة" (نشر `admin-reset-password`). والطالب يغيّرها بنفسه من أيقونة القفل في الصفحة الرئيسية. |
| الطالب غيّر/فرمت موبايله | نفس القائمة → "إعادة ضبط ارتباط الجهاز". |
| التطبيق يقفل فور الفتح | ناقص `SUPABASE_URL`/`KEY` وقت البناء (ستظهر رسالة توضح ذلك). |
| فشل البناء بعد تحديث Flutter | ثبّت رقم النسخة في `codemagic.yaml`. |
| شاشة "الجهاز غير مدعوم" | موبايل روت/محاكي (نسخة release فقط). للتجربة: `--dart-define=ALLOW_EMULATOR=true`. |
| الفيديو لا يعمل | تأكد من نشر `lecture-media` + أسرار Bunny. لو 403 ابعت لي نظام التوقيع المفعّل في Bunny. |
| Supabase المجاني يتوقف | يتوقف بعد أسبوع بلا نشاط، وفيه حد لعدد الاتصالات اللحظية (~200)؛ التطبيق يفحص الجهاز كل 45 ثانية كشبكة أمان، لكن ترقّى للخطة المدفوعة مع زيادة الطلاب. |

## قبل النشر على Google Play
- أنشئ keystore واحتفظ بنسخة احتياطية (انظر `HARDENING.md`).
- لا تفعّل `INTEGRITY_ENFORCE` إلا بعد نشر التطبيق على Play (النسخ المثبّتة يدوياً ستُرفض).
- جهّز **سياسة خصوصية** (التطبيق يجمع الأسماء وأرقام الهواتف) وراجع سياسة Google للمدفوعات (الاشتراكات تتم برموز خارج التطبيق).

## ما لا يمكن حله بالكود وحده
- **التحقق من ملكية رقم الهاتف (OTP):** يحتاج مزوّد SMS (Twilio/Vonage). حتى ذلك الحين الرقم يُفحص شكلاً فقط.
- **منع تصوير الشاشة بكاميرا أخرى:** مستحيل تقنياً؛ العلامة المائية وسجل تبديل الأجهزة هما الرادع.

## الخط الأميري (شاشة البداية)
- الخط **يُحمَّل ويُدمج وقت البناء** عبر `tool/fetch_fonts.sh` (مضاف في `codemagic.yaml`). لو استخدمت Workflow Editor أضف Pre-build script: `bash tool/fetch_fonts.sh`.
- بديل يدوي: حمّل `Amiri-Regular.ttf` و`Amiri-Bold.ttf` من Google Fonts، وضعهما في `assets/fonts/`، ثم شغّل `bash tool/fetch_fonts.sh` (أو أضف قسم fonts في pubspec يدوياً).
- لو تعذّر التحميل لا يفشل البناء: يُستخدم خط النظام العربي بدل الأميري.
