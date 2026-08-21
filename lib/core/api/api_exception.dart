// Wraps every failure shape the Laravel API can hand back so screens never
// have to parse a Dio error directly — they just show `message`, and forms
// can additionally look up `fieldErrors['email']` etc. for inline field
// feedback (standing project rule: every form shows real validation
// feedback, never fails silently).
class ApiException implements Exception {
  final String message;
  final Map<String, List<String>> fieldErrors;
  final int? statusCode;

  ApiException({required this.message, this.fieldErrors = const {}, this.statusCode});

  String? firstErrorFor(String field) => fieldErrors[field]?.first;

  factory ApiException.network() => ApiException(
        message: 'Couldn\'t connect. Check your internet connection.',
      );

  factory ApiException.fromResponseData(dynamic data, int? statusCode) {
    if (data is Map) {
      final message = data['message']?.toString() ?? 'Something went wrong. Please try again.';
      final rawErrors = data['errors'];
      final fieldErrors = <String, List<String>>{};

      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) {
            fieldErrors[key.toString()] = value.map((e) => e.toString()).toList();
          }
        });
      }

      return ApiException(message: message, fieldErrors: fieldErrors, statusCode: statusCode);
    }

    return ApiException(message: 'Something went wrong. Please try again.', statusCode: statusCode);
  }
}
