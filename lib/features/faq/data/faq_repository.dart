import '../../../core/api/api_client.dart';

class FaqItem {
  final int id;
  final String module;
  final String question;
  final String answer;

  FaqItem({required this.id, required this.module, required this.question, required this.answer});

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
        id: json['id'] as int,
        module: json['module'] as String,
        question: json['question'] as String,
        answer: json['answer'] as String,
      );
}

class FaqRepository {
  final ApiClient _client;
  FaqRepository(this._client);

  Future<List<FaqItem>> forModule(String module, {required String locale}) async {
    final data = await _client.get('/faqs', query: {'module': module, 'locale': locale});
    final list = data['faqs'] as List;
    return list.map((e) => FaqItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}
