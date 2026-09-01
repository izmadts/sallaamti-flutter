import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_store.dart';
import '../../auth/state/auth_controller.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

// The two halves of the same `courses` table: 'quran' is the Quran hub's
// Self-Paced Learning, 'skills' is the Digital Skills dashboard tile. They
// differ only in branding and copy, so every screen here takes a track
// instead of being duplicated per module.
class LearningTrack {
  final String key;
  final String title;
  final String emoji;
  final String tagline;

  const LearningTrack({required this.key, required this.title, required this.emoji, required this.tagline});

  static const quran = LearningTrack(
    key: 'quran',
    title: 'Self-Paced Quran',
    emoji: '📖',
    tagline: 'Recorded lessons you can work through whenever suits you.',
  );

  static const skills = LearningTrack(
    key: 'skills',
    title: 'Digital Skills',
    emoji: '💻',
    tagline: 'Practical, job-ready skills — learn at your own pace.',
  );

  /// The module key its theme comes from (ModuleThemes), not the track key.
  String get moduleKey => key == 'skills' ? 'skills' : 'quran';

  static LearningTrack fromKey(String? key) => key == 'skills' ? skills : quran;
}

class LearningQuizSummary {
  final int id;
  final String title;
  final int passingPercentage;
  final bool passed;

  LearningQuizSummary({required this.id, required this.title, required this.passingPercentage, required this.passed});

  factory LearningQuizSummary.fromJson(Map<String, dynamic> json) => LearningQuizSummary(
        id: _asInt(json['id']) ?? 0,
        title: json['title'] as String? ?? 'Quiz',
        passingPercentage: _asInt(json['passing_percentage']) ?? 0,
        passed: json['passed'] as bool? ?? false,
      );
}

class LearningQuizAttempt {
  final int id;
  final int scorePercentage;
  final bool passed;
  final DateTime? createdAt;

  LearningQuizAttempt({required this.id, required this.scorePercentage, required this.passed, this.createdAt});

  factory LearningQuizAttempt.fromJson(Map<String, dynamic> json) => LearningQuizAttempt(
        id: _asInt(json['id']) ?? 0,
        scorePercentage: _asInt(json['score_percentage']) ?? 0,
        passed: json['passed'] as bool? ?? false,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}

class LearningQuizQuestion {
  final int id;
  final String question;
  final List<String> options;

  LearningQuizQuestion({required this.id, required this.question, required this.options});

  factory LearningQuizQuestion.fromJson(Map<String, dynamic> json) => LearningQuizQuestion(
        id: _asInt(json['id']) ?? 0,
        question: json['question'] as String? ?? '',
        options: json['options'] != null ? (json['options'] as List).map((e) => e.toString()).toList() : const [],
      );
}

class LearningQuizDetail {
  final int id;
  final String title;
  final int passingPercentage;
  final List<LearningQuizQuestion> questions;
  final LearningQuizAttempt? bestAttempt;

  LearningQuizDetail({
    required this.id,
    required this.title,
    required this.passingPercentage,
    required this.questions,
    this.bestAttempt,
  });

  factory LearningQuizDetail.fromJson(Map<String, dynamic> json) {
    final quiz = Map<String, dynamic>.from(json['quiz'] as Map);

    return LearningQuizDetail(
      id: _asInt(quiz['id']) ?? 0,
      title: quiz['title'] as String? ?? 'Quiz',
      passingPercentage: _asInt(quiz['passing_percentage']) ?? 0,
      questions: (quiz['questions'] as List)
          .map((e) => LearningQuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bestAttempt: json['best_attempt'] != null
          ? LearningQuizAttempt.fromJson(Map<String, dynamic>.from(json['best_attempt'] as Map))
          : null,
    );
  }
}

class LearningCourse {
  final int id;
  final String? slug;
  final String title;
  final String? description;
  final String? category;
  final String track;
  final String? level;
  final int? minAge;
  final int? maxAge;
  final String? thumbnailUrl;
  final int lessonsCount;
  final bool isEnrolled;
  final int completedLessons;
  final int progress;
  final DateTime? enrolledAt;

  LearningCourse({
    required this.id,
    this.slug,
    required this.title,
    this.description,
    this.category,
    required this.track,
    this.level,
    this.minAge,
    this.maxAge,
    this.thumbnailUrl,
    required this.lessonsCount,
    required this.isEnrolled,
    required this.completedLessons,
    required this.progress,
    this.enrolledAt,
  });

  factory LearningCourse.fromJson(Map<String, dynamic> json) => LearningCourse(
        id: _asInt(json['id']) ?? 0,
        slug: json['slug'] as String?,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        category: json['category'] as String?,
        track: json['track'] as String? ?? 'quran',
        level: json['level'] as String?,
        minAge: _asInt(json['min_age']),
        maxAge: _asInt(json['max_age']),
        thumbnailUrl: json['thumbnail_url'] as String?,
        lessonsCount: _asInt(json['lessons_count']) ?? 0,
        isEnrolled: json['is_enrolled'] as bool? ?? false,
        completedLessons: _asInt(json['completed_lessons']) ?? 0,
        progress: _asInt(json['progress']) ?? 0,
        enrolledAt: json['enrolled_at'] != null ? DateTime.tryParse(json['enrolled_at'] as String) : null,
      );
}

class LearningLessonSummary {
  final int id;
  final String title;
  final int order;
  final bool hasVideo;
  final bool hasFile;
  final bool isCompleted;
  final LearningQuizSummary? quiz;

  LearningLessonSummary({
    required this.id,
    required this.title,
    required this.order,
    required this.hasVideo,
    required this.hasFile,
    required this.isCompleted,
    this.quiz,
  });

  factory LearningLessonSummary.fromJson(Map<String, dynamic> json) => LearningLessonSummary(
        id: _asInt(json['id']) ?? 0,
        title: json['title'] as String? ?? '',
        order: _asInt(json['order']) ?? 0,
        hasVideo: json['has_video'] as bool? ?? false,
        hasFile: json['has_file'] as bool? ?? false,
        isCompleted: json['is_completed'] as bool? ?? false,
        quiz: json['quiz'] != null ? LearningQuizSummary.fromJson(Map<String, dynamic>.from(json['quiz'] as Map)) : null,
      );
}

class LearningCertificate {
  final int id;
  // Null while pending/rejected — a course-completion request has neither
  // a real number nor an issue date until an admin approves it.
  final String? certificateNumber;
  final String title;
  final String? type;
  final int? courseId;
  final String status;
  final String? rejectionReason;
  final DateTime? issuedAt;

  LearningCertificate({
    required this.id,
    this.certificateNumber,
    required this.title,
    this.type,
    this.courseId,
    required this.status,
    this.rejectionReason,
    this.issuedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory LearningCertificate.fromJson(Map<String, dynamic> json) => LearningCertificate(
        id: _asInt(json['id']) ?? 0,
        certificateNumber: json['certificate_number'] as String?,
        title: json['title'] as String? ?? 'Certificate',
        type: json['type'] as String?,
        courseId: _asInt(json['course_id']),
        status: json['status'] as String? ?? 'approved',
        rejectionReason: json['rejection_reason'] as String?,
        issuedAt: json['issued_at'] != null ? DateTime.tryParse(json['issued_at'] as String) : null,
      );
}

class LearningCourseDetail {
  final LearningCourse course;
  final List<LearningLessonSummary> lessons;
  final LearningQuizSummary? finalQuiz;
  final bool finalQuizUnlocked;
  final bool certificateEligible;
  final LearningCertificate? certificate;

  LearningCourseDetail({
    required this.course,
    required this.lessons,
    this.finalQuiz,
    required this.finalQuizUnlocked,
    required this.certificateEligible,
    this.certificate,
  });

  factory LearningCourseDetail.fromJson(Map<String, dynamic> json) => LearningCourseDetail(
        course: LearningCourse.fromJson(Map<String, dynamic>.from(json['course'] as Map)),
        lessons: (json['lessons'] as List)
            .map((e) => LearningLessonSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        finalQuiz: json['final_quiz'] != null
            ? LearningQuizSummary.fromJson(Map<String, dynamic>.from(json['final_quiz'] as Map))
            : null,
        finalQuizUnlocked: json['final_quiz_unlocked'] as bool? ?? false,
        certificateEligible: json['certificate_eligible'] as bool? ?? false,
        certificate: json['certificate'] != null
            ? LearningCertificate.fromJson(Map<String, dynamic>.from(json['certificate'] as Map))
            : null,
      );
}

class LearningLessonDetail {
  final int id;
  final String title;
  final String? content;
  final String? videoUrl;
  final String? embedUrl;
  final String? fileUrl;
  final String? fileName;
  final bool isCompleted;
  final int secondsRemaining;
  final LearningQuizSummary? quiz;
  final int courseId;
  final String courseTitle;
  final String courseTrack;
  final int? previousLessonId;
  final int? nextLessonId;

  LearningLessonDetail({
    required this.id,
    required this.title,
    this.content,
    this.videoUrl,
    this.embedUrl,
    this.fileUrl,
    this.fileName,
    required this.isCompleted,
    required this.secondsRemaining,
    this.quiz,
    required this.courseId,
    required this.courseTitle,
    required this.courseTrack,
    this.previousLessonId,
    this.nextLessonId,
  });

  factory LearningLessonDetail.fromJson(Map<String, dynamic> json) {
    final lesson = Map<String, dynamic>.from(json['lesson'] as Map);
    final course = Map<String, dynamic>.from(json['course'] as Map);

    return LearningLessonDetail(
      id: _asInt(lesson['id']) ?? 0,
      title: lesson['title'] as String? ?? '',
      content: lesson['content'] as String?,
      videoUrl: lesson['video_url'] as String?,
      embedUrl: lesson['embed_url'] as String?,
      fileUrl: lesson['file_url'] as String?,
      fileName: lesson['file_name'] as String?,
      isCompleted: lesson['is_completed'] as bool? ?? false,
      secondsRemaining: _asInt(lesson['seconds_remaining']) ?? 0,
      quiz: lesson['quiz'] != null ? LearningQuizSummary.fromJson(Map<String, dynamic>.from(lesson['quiz'] as Map)) : null,
      courseId: _asInt(course['id']) ?? 0,
      courseTitle: course['title'] as String? ?? '',
      courseTrack: course['track'] as String? ?? 'quran',
      previousLessonId: _asInt(json['previous_lesson_id']),
      nextLessonId: _asInt(json['next_lesson_id']),
    );
  }
}

class LearningCatalog {
  final List<LearningCourse> courses;
  final List<String> categories;

  LearningCatalog({required this.courses, required this.categories});
}

class LearningRepository {
  final ApiClient _client;
  LearningRepository(this._client);

  Future<LearningCatalog> courses({required String track, String? category}) async {
    final data = await _client.get('/learning/courses', query: {
      'track': track,
      if (category != null && category.isNotEmpty) 'category': category,
    });

    return LearningCatalog(
      courses: (data['courses'] as List).map((e) => LearningCourse.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      categories: (data['categories'] as List).map((e) => e.toString()).toList(),
    );
  }

  Future<LearningCourseDetail> courseDetail(int courseId) async {
    final data = await _client.get('/learning/courses/$courseId');
    return LearningCourseDetail.fromJson(data);
  }

  Future<String> enroll(int courseId) async {
    final data = await _client.post('/learning/courses/$courseId/enroll');
    return data['message'] as String? ?? 'Enrolled successfully!';
  }

  Future<List<LearningCourse>> myLearning() async {
    final data = await _client.get('/learning/my-learning');
    return (data['courses'] as List).map((e) => LearningCourse.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<LearningLessonDetail> lesson(int lessonId) async {
    final data = await _client.get('/learning/lessons/$lessonId');
    return LearningLessonDetail.fromJson(data);
  }

  Future<String> completeLesson(int lessonId) async {
    final data = await _client.post('/learning/lessons/$lessonId/complete');
    return data['message'] as String? ?? 'Lesson marked complete!';
  }

  Future<LearningQuizDetail> lessonQuiz(int lessonId) async {
    final data = await _client.get('/learning/lessons/$lessonId/quiz');
    return LearningQuizDetail.fromJson(data);
  }

  Future<LearningQuizDetail> courseQuiz(int courseId) async {
    final data = await _client.get('/learning/courses/$courseId/quiz');
    return LearningQuizDetail.fromJson(data);
  }

  // answers is {questionId: chosenOptionIndex}; the keys go over the wire as
  // strings and the backend casts them back to ints.
  Future<(LearningQuizAttempt, String)> submitLessonQuiz(int lessonId, Map<int, int> answers) =>
      _submitQuiz('/learning/lessons/$lessonId/quiz', answers);

  Future<(LearningQuizAttempt, String)> submitCourseQuiz(int courseId, Map<int, int> answers) =>
      _submitQuiz('/learning/courses/$courseId/quiz', answers);

  Future<(LearningQuizAttempt, String)> _submitQuiz(String path, Map<int, int> answers) async {
    final data = await _client.post(path, data: {
      'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
    });

    return (
      LearningQuizAttempt.fromJson(Map<String, dynamic>.from(data['attempt'] as Map)),
      data['message'] as String? ?? '',
    );
  }

  Future<LearningCertificate> generateCertificate(int courseId) async {
    final data = await _client.post('/learning/courses/$courseId/certificate');
    return LearningCertificate.fromJson(Map<String, dynamic>.from(data['certificate'] as Map));
  }

  Future<List<LearningCertificate>> certificates() async {
    final data = await _client.get('/learning/certificates');
    return (data['certificates'] as List)
        .map((e) => LearningCertificate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // The PDF endpoint isn't JSON, so this talks to Dio directly rather than
  // through ApiClient's helpers — same base URL and bearer token, but the
  // bytes go straight to a temp file for share_plus to hand to the OS. Same
  // approach the Nikah Counselor app uses for its ID card.
  Future<File> downloadCertificate(LearningCertificate certificate) async {
    final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    final token = await SecureStore.readToken();

    final response = await dio.get<List<int>>(
      '/learning/certificates/${certificate.id}/download',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Sallaamti-Certificate-${certificate.certificateNumber}.pdf');
    await file.writeAsBytes(response.data!);
    return file;
  }
}

final learningRepositoryProvider = Provider((ref) => LearningRepository(ref.watch(apiClientProvider)));
