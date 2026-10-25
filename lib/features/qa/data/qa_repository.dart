import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';
import '../../community/data/community_repository.dart' show Paged;
import '../domain/question.dart';

class QaRepository {
  final ApiClient _client;
  QaRepository(this._client);

  Future<Paged<Question>> questions({int page = 1}) async {
    final data = await _client.get('/questions', query: {'page': page});
    return Paged.fromJson(data, 'questions', Question.fromJson);
  }

  Future<Paged<Question>> myQuestions({int page = 1}) async {
    final data = await _client.get('/questions/mine', query: {'page': page});
    return Paged.fromJson(data, 'questions', Question.fromJson);
  }

  Future<(Question, String)> ask(String question) async {
    final data = await _client.post('/questions', data: {'question': question});
    return (
      Question.fromJson(Map<String, dynamic>.from(data['question'] as Map)),
      data['message'] as String? ?? '',
    );
  }
}

final qaRepositoryProvider = Provider((ref) => QaRepository(ref.watch(apiClientProvider)));
