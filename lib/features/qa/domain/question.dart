int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class Question {
  final int id;
  final String question;
  final String? answer;
  final String status;
  final DateTime? answeredAt;
  final DateTime? createdAt;
  final bool isMine;

  Question({
    required this.id,
    required this.question,
    this.answer,
    required this.status,
    this.answeredAt,
    this.createdAt,
    this.isMine = false,
  });

  bool get isAnswered => status == 'answered';

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: _asInt(json['id']) ?? 0,
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String?,
        status: json['status'] as String? ?? 'pending',
        answeredAt: json['answered_at'] != null ? DateTime.tryParse(json['answered_at'] as String) : null,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        isMine: json['is_mine'] as bool? ?? false,
      );
}
