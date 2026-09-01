import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

const quranLiveTeacherPreferences = {
  'no_preference': 'No Preference',
  'male': 'Male Teacher',
  'female': 'Female Teacher',
};

const quranLiveClassTypes = {
  'group': 'Group Class',
  'one_to_one': 'One-to-One (Private)',
};

class QuranLivePerson {
  final int id;
  final String name;
  final String? avatar;
  QuranLivePerson({required this.id, required this.name, this.avatar});

  factory QuranLivePerson.fromJson(Map<String, dynamic> json) => QuranLivePerson(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
      );
}

class QuranLiveLevel {
  final String title;
  final int? levelNumber;
  QuranLiveLevel({required this.title, this.levelNumber});

  factory QuranLiveLevel.fromJson(Map<String, dynamic> json) => QuranLiveLevel(
        title: json['title'] as String,
        levelNumber: _asInt(json['level_number']),
      );
}

class QuranLiveMeta {
  final List<String> grades;
  final List<String> days;
  final List<String> times;
  final Map<String, String> teacherPreferences;
  final Map<String, String> classTypes;
  final List<QuranLiveLevel> levels;
  final List<String> timezones;

  QuranLiveMeta({
    required this.grades,
    required this.days,
    required this.times,
    required this.teacherPreferences,
    required this.classTypes,
    required this.levels,
    required this.timezones,
  });

  factory QuranLiveMeta.fromJson(Map<String, dynamic> json) => QuranLiveMeta(
        grades: (json['grades'] as List).map((e) => e.toString()).toList(),
        days: (json['days'] as List).map((e) => e.toString()).toList(),
        times: (json['times'] as List).map((e) => e.toString()).toList(),
        teacherPreferences: Map<String, String>.from(json['teacher_preferences'] as Map),
        classTypes: Map<String, String>.from(json['class_types'] as Map),
        levels: (json['levels'] as List).map((e) => QuranLiveLevel.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        timezones: (json['timezones'] as List).map((e) => e.toString()).toList(),
      );
}

class QuranLiveCourseInfo {
  final int id;
  final String title;
  final String? description;
  final String? category;
  final int? levelNumber;
  final int? minAge;
  final int? maxAge;
  final String? duration;
  final List<String> topics;
  final String? outcome;
  final String? genderPreference;
  final List<String> classDays;
  final String? classTime;
  final String monthlyFee;
  final QuranLivePerson? teacher;

  QuranLiveCourseInfo({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.levelNumber,
    this.minAge,
    this.maxAge,
    this.duration,
    this.topics = const [],
    this.outcome,
    this.genderPreference,
    this.classDays = const [],
    this.classTime,
    required this.monthlyFee,
    this.teacher,
  });

  factory QuranLiveCourseInfo.fromJson(Map<String, dynamic> json) => QuranLiveCourseInfo(
        id: _asInt(json['id']) ?? 0,
        title: json['title'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        levelNumber: _asInt(json['level_number']),
        minAge: _asInt(json['min_age']),
        maxAge: _asInt(json['max_age']),
        duration: json['duration'] as String?,
        topics: json['topics'] != null ? (json['topics'] as List).map((e) => e.toString()).toList() : const [],
        outcome: json['outcome'] as String?,
        genderPreference: json['gender_preference'] as String?,
        classDays: json['class_days'] != null ? (json['class_days'] as List).map((e) => e.toString()).toList() : const [],
        classTime: json['class_time'] as String?,
        monthlyFee: json['monthly_fee']?.toString() ?? '0',
        teacher: json['teacher'] != null ? QuranLivePerson.fromJson(Map<String, dynamic>.from(json['teacher'] as Map)) : null,
      );
}

class QuranLiveSubscriptionInfo {
  final int id;
  final String month;
  final String amount;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paymentReference;
  final String? paymentRejectionReason;

  QuranLiveSubscriptionInfo({
    required this.id,
    required this.month,
    required this.amount,
    required this.paymentStatus,
    this.paymentMethod,
    this.paymentReference,
    this.paymentRejectionReason,
  });

  factory QuranLiveSubscriptionInfo.fromJson(Map<String, dynamic> json) => QuranLiveSubscriptionInfo(
        id: _asInt(json['id']) ?? 0,
        month: json['month'] as String,
        amount: json['amount']?.toString() ?? '0',
        paymentStatus: json['payment_status'] as String,
        paymentMethod: json['payment_method'] as String?,
        paymentReference: json['payment_reference'] as String?,
        paymentRejectionReason: json['payment_rejection_reason'] as String?,
      );
}

class QuranLiveLinkInfo {
  final String joinUrl;
  final String? passcode;
  QuranLiveLinkInfo({required this.joinUrl, this.passcode});

  factory QuranLiveLinkInfo.fromJson(Map<String, dynamic> json) => QuranLiveLinkInfo(
        joinUrl: json['join_url'] as String,
        passcode: json['passcode'] as String?,
      );
}

class QuranLivePaymentInstructions {
  final String? jazzcashNumber;
  final String? jazzcashAccountTitle;
  final String? bankName;
  final String? bankAccountTitle;
  final String? bankAccountNumber;
  final String? bankAccountIban;

  QuranLivePaymentInstructions({
    this.jazzcashNumber,
    this.jazzcashAccountTitle,
    this.bankName,
    this.bankAccountTitle,
    this.bankAccountNumber,
    this.bankAccountIban,
  });

  bool get hasJazzcash => (jazzcashNumber ?? '').isNotEmpty;
  bool get hasBankTransfer => (bankName ?? '').isNotEmpty;
  bool get hasAnyMethod => hasJazzcash || hasBankTransfer;

  factory QuranLivePaymentInstructions.fromJson(Map<String, dynamic> json) => QuranLivePaymentInstructions(
        jazzcashNumber: json['jazzcash_number'] as String?,
        jazzcashAccountTitle: json['jazzcash_account_title'] as String?,
        bankName: json['bank_name'] as String?,
        bankAccountTitle: json['bank_account_title'] as String?,
        bankAccountNumber: json['bank_account_number'] as String?,
        bankAccountIban: json['bank_account_iban'] as String?,
      );
}

class QuranLiveAdmissionInfo {
  final int id;
  final int courseId;
  final String studentName;
  final String status;
  final QuranLiveSubscriptionInfo? subscription;
  final QuranLiveLinkInfo? todaysLink;

  QuranLiveAdmissionInfo({
    required this.id,
    required this.courseId,
    required this.studentName,
    required this.status,
    this.subscription,
    this.todaysLink,
  });

  factory QuranLiveAdmissionInfo.fromJson(Map<String, dynamic> json) => QuranLiveAdmissionInfo(
        id: _asInt(json['id']) ?? 0,
        courseId: _asInt(json['course_id']) ?? 0,
        studentName: json['student_name'] as String,
        status: json['status'] as String,
        subscription: json['subscription'] != null ? QuranLiveSubscriptionInfo.fromJson(Map<String, dynamic>.from(json['subscription'] as Map)) : null,
        todaysLink: json['todays_link'] != null ? QuranLiveLinkInfo.fromJson(Map<String, dynamic>.from(json['todays_link'] as Map)) : null,
      );
}

class QuranLiveApplicationInfo {
  final int id;
  final String studentName;
  final String courseTitle;
  final String status;
  final String? preferredTime;
  final String? teacherPreference;

  QuranLiveApplicationInfo({
    required this.id,
    required this.studentName,
    required this.courseTitle,
    required this.status,
    this.preferredTime,
    this.teacherPreference,
  });

  factory QuranLiveApplicationInfo.fromJson(Map<String, dynamic> json) => QuranLiveApplicationInfo(
        id: _asInt(json['id']) ?? 0,
        studentName: json['student_name'] as String,
        courseTitle: json['course_title'] as String,
        status: json['status'] as String,
        preferredTime: json['preferred_time'] as String?,
        teacherPreference: json['teacher_preference'] as String?,
      );
}

class QuranLiveGroupStudentInfo {
  final int id;
  final int admissionId;
  final String studentName;
  final String courseTitle;
  final String groupName;
  final QuranLivePerson? teacher;
  final List<String> classDays;
  final String? classTime;
  final String? timezone;
  final QuranLiveSubscriptionInfo? subscription;
  final QuranLiveLinkInfo? todaysLink;

  QuranLiveGroupStudentInfo({
    required this.id,
    required this.admissionId,
    required this.studentName,
    required this.courseTitle,
    required this.groupName,
    this.teacher,
    this.classDays = const [],
    this.classTime,
    this.timezone,
    this.subscription,
    this.todaysLink,
  });

  factory QuranLiveGroupStudentInfo.fromJson(Map<String, dynamic> json) => QuranLiveGroupStudentInfo(
        id: _asInt(json['id']) ?? 0,
        admissionId: _asInt(json['admission_id']) ?? 0,
        studentName: json['student_name'] as String? ?? '—',
        courseTitle: json['course_title'] as String,
        groupName: json['group_name'] as String,
        teacher: json['teacher'] != null ? QuranLivePerson.fromJson(Map<String, dynamic>.from(json['teacher'] as Map)) : null,
        classDays: json['class_days'] != null ? (json['class_days'] as List).map((e) => e.toString()).toList() : const [],
        classTime: json['class_time'] as String?,
        timezone: json['timezone'] as String?,
        subscription: json['subscription'] != null ? QuranLiveSubscriptionInfo.fromJson(Map<String, dynamic>.from(json['subscription'] as Map)) : null,
        todaysLink: json['todays_link'] != null ? QuranLiveLinkInfo.fromJson(Map<String, dynamic>.from(json['todays_link'] as Map)) : null,
      );
}

class QuranLiveMessageInfo {
  final int id;
  final String message;
  final bool isMine;
  final String? senderName;
  final DateTime createdAt;

  QuranLiveMessageInfo({required this.id, required this.message, required this.isMine, this.senderName, required this.createdAt});

  factory QuranLiveMessageInfo.fromJson(Map<String, dynamic> json) => QuranLiveMessageInfo(
        id: _asInt(json['id']) ?? 0,
        message: json['message'] as String,
        isMine: json['is_mine'] as bool? ?? false,
        senderName: json['sender_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class QuranLiveMyClass {
  final List<QuranLiveApplicationInfo> admissions;
  final List<QuranLiveGroupStudentInfo> groupStudents;
  final int? currentId;
  final List<QuranLiveMessageInfo> messages;

  QuranLiveMyClass({required this.admissions, required this.groupStudents, this.currentId, this.messages = const []});

  factory QuranLiveMyClass.fromJson(Map<String, dynamic> json) => QuranLiveMyClass(
        admissions: (json['admissions'] as List).map((e) => QuranLiveApplicationInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        groupStudents: (json['group_students'] as List).map((e) => QuranLiveGroupStudentInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        currentId: _asInt(json['current_id']),
        messages: json['messages'] != null
            ? (json['messages'] as List).map((e) => QuranLiveMessageInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            : const [],
      );
}

class QuranLiveAssessmentInfo {
  final int id;
  final String type;
  final String score;
  final String grade;
  final String? remarks;
  final String assessmentDate;

  QuranLiveAssessmentInfo({required this.id, required this.type, required this.score, required this.grade, this.remarks, required this.assessmentDate});

  factory QuranLiveAssessmentInfo.fromJson(Map<String, dynamic> json) => QuranLiveAssessmentInfo(
        id: _asInt(json['id']) ?? 0,
        type: json['type'] as String,
        score: json['score']?.toString() ?? '0',
        grade: json['grade'] as String,
        remarks: json['remarks'] as String?,
        assessmentDate: json['assessment_date'] as String,
      );
}

class QuranLiveProgressReportInfo {
  final int id;
  final String month;
  final int classesAttended;
  final int classesTotal;
  final String? quranProgress;
  final String? behavior;
  final String? homeworkCompletion;
  final String? teacherComments;
  final String overallRating;

  QuranLiveProgressReportInfo({
    required this.id,
    required this.month,
    required this.classesAttended,
    required this.classesTotal,
    this.quranProgress,
    this.behavior,
    this.homeworkCompletion,
    this.teacherComments,
    required this.overallRating,
  });

  factory QuranLiveProgressReportInfo.fromJson(Map<String, dynamic> json) => QuranLiveProgressReportInfo(
        id: _asInt(json['id']) ?? 0,
        month: json['month'] as String,
        classesAttended: _asInt(json['classes_attended']) ?? 0,
        classesTotal: _asInt(json['classes_total']) ?? 0,
        quranProgress: json['quran_progress'] as String?,
        behavior: json['behavior'] as String?,
        homeworkCompletion: json['homework_completion'] as String?,
        teacherComments: json['teacher_comments'] as String?,
        overallRating: json['overall_rating'] as String,
      );
}

// Just enough to render the child-switcher chips on the progress screen —
// the my-progress endpoint doesn't send the full group/course/teacher
// payload QuranLiveGroupStudentInfo expects, since that screen never shows
// any of it.
class QuranLiveChildSummary {
  final int id;
  final String studentName;
  QuranLiveChildSummary({required this.id, required this.studentName});

  factory QuranLiveChildSummary.fromJson(Map<String, dynamic> json) => QuranLiveChildSummary(
        id: _asInt(json['id']) ?? 0,
        studentName: json['student_name'] as String? ?? '—',
      );
}

class QuranLiveProgress {
  final List<QuranLiveChildSummary> groupStudents;
  final int? currentId;
  final List<QuranLiveAssessmentInfo> assessments;
  final List<QuranLiveProgressReportInfo> progressReports;

  QuranLiveProgress({required this.groupStudents, this.currentId, required this.assessments, required this.progressReports});
}

class QuranLiveRepository {
  final ApiClient _client;
  QuranLiveRepository(this._client);

  Future<QuranLiveMeta> meta() async {
    final data = await _client.get('/quran-live/meta');
    return QuranLiveMeta.fromJson(data);
  }

  Future<List<QuranLiveCourseInfo>> courses() async {
    final data = await _client.get('/quran-live/courses');
    return (data['courses'] as List).map((e) => QuranLiveCourseInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<(QuranLiveCourseInfo, List<QuranLiveAdmissionInfo>)> courseDetail(int courseId) async {
    final data = await _client.get('/quran-live/courses/$courseId');
    final course = QuranLiveCourseInfo.fromJson(Map<String, dynamic>.from(data['course'] as Map));
    final admissions =
        (data['admissions'] as List).map((e) => QuranLiveAdmissionInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return (course, admissions);
  }

  Future<QuranLiveAdmissionInfo> storeAdmission({
    required int courseId,
    required String guardianName,
    required String whatsappNumber,
    required String country,
    String? cityState,
    required String studentName,
    required String studentGender,
    required int studentAge,
    String? educationGrade,
    bool learnedQuranBefore = false,
    List<String> preferredDays = const [],
    String? preferredTime,
    required String teacherPreference,
    String? comments,
    String? selectedLevel,
    String? previousLevel,
    String? classType,
    String? timezone,
  }) async {
    final data = await _client.post('/quran-live/courses/$courseId/admissions', data: {
      'guardian_name': guardianName,
      'whatsapp_number': whatsappNumber,
      'country': country,
      'city_state': cityState,
      'student_name': studentName,
      'student_gender': studentGender,
      'student_age': studentAge,
      'education_grade': educationGrade,
      'learned_quran_before': learnedQuranBefore,
      'preferred_days': preferredDays,
      'preferred_time': preferredTime,
      'teacher_preference': teacherPreference,
      'comments': comments,
      'selected_level': selectedLevel,
      'previous_level': previousLevel,
      'class_type': classType,
      'timezone': timezone,
      'declaration_accepted': true,
    });
    return QuranLiveAdmissionInfo.fromJson(Map<String, dynamic>.from(data['admission'] as Map));
  }

  Future<(QuranLiveSubscriptionInfo?, String, String, QuranLivePaymentInstructions)> subscription(int admissionId) async {
    final data = await _client.get('/quran-live/admissions/$admissionId/subscription');
    final subscription = data['subscription'] != null ? QuranLiveSubscriptionInfo.fromJson(Map<String, dynamic>.from(data['subscription'] as Map)) : null;
    final instructions = QuranLivePaymentInstructions.fromJson(Map<String, dynamic>.from(data['payment_instructions'] as Map));
    return (subscription, data['month'] as String, data['amount']?.toString() ?? '0', instructions);
  }

  Future<QuranLiveSubscriptionInfo> storeSubscription({
    required int admissionId,
    required String paymentMethod,
    required String paymentReference,
    required File screenshot,
  }) async {
    final data = await _client.postMultipart('/quran-live/admissions/$admissionId/subscription', fields: {
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
    }, files: {
      'payment_screenshot': screenshot,
    });
    return QuranLiveSubscriptionInfo.fromJson(Map<String, dynamic>.from(data['subscription'] as Map));
  }

  Future<QuranLiveMyClass> myClass({int? childId}) async {
    final data = await _client.get('/quran-live/my-class', query: childId != null ? {'child': childId} : null);
    return QuranLiveMyClass.fromJson(data);
  }

  Future<QuranLiveMessageInfo> sendMessage(int admissionId, String message) async {
    final data = await _client.post('/quran-live/admissions/$admissionId/messages', data: {'message': message});
    return QuranLiveMessageInfo.fromJson(Map<String, dynamic>.from(data['message'] as Map));
  }

  Future<QuranLiveProgress> myProgress({int? childId}) async {
    final data = await _client.get('/quran-live/my-progress', query: childId != null ? {'child': childId} : null);
    return QuranLiveProgress(
      groupStudents: (data['group_students'] as List).map((e) => QuranLiveChildSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      currentId: _asInt(data['current_id']),
      assessments: (data['assessments'] as List).map((e) => QuranLiveAssessmentInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      progressReports:
          (data['progress_reports'] as List).map((e) => QuranLiveProgressReportInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

final quranLiveRepositoryProvider = Provider((ref) => QuranLiveRepository(ref.watch(apiClientProvider)));
