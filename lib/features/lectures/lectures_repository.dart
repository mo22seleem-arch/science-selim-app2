import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/security/security_service.dart';
import '../../core/services/device_service.dart';

class Lecture {
  final String id, unitId, title; final String? provider, videoRef, pdfPath;
  Lecture(this.id, this.unitId, this.title, this.provider, this.videoRef, this.pdfPath);
  factory Lecture.fromMap(Map<String, dynamic> m) =>
      Lecture(m['id'], m['unit_id'], m['title'], m['video_provider'], m['video_ref'], m['pdf_path']);
  bool get hasVideo => (videoRef ?? '').isNotEmpty;
  bool get hasPdf => (pdfPath ?? '').isNotEmpty;
}

class LecturesRepository {
  final _db = Supabase.instance.client;

  // ---------- student ----------
  Future<List<Lecture>> lectures(String unitId) async {
    final r = await _db.from('lectures').select().eq('unit_id', unitId).order('sort_order').order('title');
    return r.map(Lecture.fromMap).toList();
  }
  Future<Map<String, dynamic>?> quizFor(String lectureId) =>
      _db.from('quizzes').select().eq('lecture_id', lectureId).maybeSingle();
  Future<List<Map<String, dynamic>>> questions(String quizId) =>
      _db.from('questions').select().eq('quiz_id', quizId).order('sort_order');

  /// kind: 'video' | 'pdf'. The Edge Function checks device + entitlement and returns a short-lived URL.
  Future<String> mediaUrl(String lectureId, String kind, {bool retried = false}) async {
    final d = await DeviceService.info();
    try {
      final res = await _db.functions.invoke('lecture-media', body: {'lecture_id': lectureId, 'kind': kind, 'device_id': d.id});
      final data = res.data;
      if (data is Map && data['url'] is String) return data['url'];
    } on FunctionException catch (e) {
      final det = e.details;
      if (!retried && det is Map && det['error'] == 'integrity_required' && await IntegrityService.attest()) {
        return mediaUrl(lectureId, kind, retried: true);
      }
    }
    throw Exception('media_failed');
  }

  Future<Map<String, dynamic>> submitQuiz(String quizId, Map<String, int> answers) async =>
      Map<String, dynamic>.from(await _db.rpc('submit_quiz', params: {'p_quiz': quizId, 'p_answers': answers}));

  // ---------- admin ----------
  Future<String> saveLecture({String? id, required String unitId, required String title, String? provider, String? videoRef, int order = 0}) async {
    final row = {'unit_id': unitId, 'title': title.trim(), 'video_provider': (videoRef ?? '').trim().isEmpty ? null : provider,
      'video_ref': (videoRef ?? '').trim().isEmpty ? null : videoRef!.trim(), 'sort_order': order};
    if (id == null) return (await _db.from('lectures').insert(row).select('id').single())['id'];
    await _db.from('lectures').update(row).eq('id', id); return id;
  }
  Future<void> uploadPdf(String lectureId, List<int> bytes) async {
    final path = '$lectureId/${DateTime.now().millisecondsSinceEpoch}.pdf';
    await _db.storage.from('lecture-pdfs').uploadBinary(path, bytes as dynamic,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
    await _db.from('lectures').update({'pdf_path': path}).eq('id', lectureId);
  }
  Future<void> removePdf(Lecture l) async {
    if (l.hasPdf) await _db.storage.from('lecture-pdfs').remove([l.pdfPath!]);
    await _db.from('lectures').update({'pdf_path': null}).eq('id', l.id);
  }
  Future<void> deleteLecture(Lecture l) async {
    if (l.hasPdf) { try { await _db.storage.from('lecture-pdfs').remove([l.pdfPath!]); } catch (_) {} }
    await _db.from('lectures').delete().eq('id', l.id);
  }

  Future<String> createQuiz(String lectureId, int passPercent) async =>
      (await _db.from('quizzes').insert({'lecture_id': lectureId, 'title': 'اختبار', 'pass_percent': passPercent}).select('id').single())['id'];
  Future<void> setPass(String quizId, int p) => _db.from('quizzes').update({'pass_percent': p}).eq('id', quizId);
  Future<void> deleteQuiz(String quizId) => _db.from('quizzes').delete().eq('id', quizId);
  Future<List<Map<String, dynamic>>> questionsWithKeys(String quizId) =>
      _db.from('questions').select('*, question_keys(correct_index)').eq('quiz_id', quizId).order('sort_order');
  Future<void> addQuestion(String quizId, String body, List<String> options, int correct, int order) async {
    final q = await _db.from('questions').insert({'quiz_id': quizId, 'body': body.trim(), 'options': options, 'sort_order': order}).select('id').single();
    try { await _db.from('question_keys').insert({'question_id': q['id'], 'correct_index': correct}); }
    catch (e) { await _db.from('questions').delete().eq('id', q['id']); rethrow; }
  }
  Future<void> deleteQuestion(String id) => _db.from('questions').delete().eq('id', id);
}
