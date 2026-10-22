// Wraps every failure shape the Laravel API can hand back so screens never
// have to parse a Dio error directly — they just show `message`, and forms
// can additionally look up `fieldErrors['email']` etc. for inline field
// feedback (standing project rule: every form shows real validation
// feedback, never fails silently).
class ApiException implements Exception {
  final String message;
  final Map<String, List<String>> fieldErrors;
  final int? statusCode;
  // Some endpoints (e.g. NikahBrowseController's gate responses) carry a
  // stable machine-readable `code` alongside the human message, so a screen
  // can branch on the exact reason — e.g. silently redirecting to fix a
  // missing gender instead of showing a generic locked-screen error for
  // something that isn't really a failure, just a missing setup step.
  final String? code;

  ApiException({required this.message, this.fieldErrors = const {}, this.statusCode, this.code});

  String? firstErrorFor(String field) => fieldErrors[field]?.first;

  // Laravel's top-level `message` on a 422 is a generic "The given data
  // was invalid." — the actually useful, specific text is the first field
  // error. Screens that don't know which single field to look up (the
  // Nikah wizard steps, which each submit several fields at once) use
  // this instead of `message` directly.
  String get displayMessage {
    if (fieldErrors.isNotEmpty) {
      return fieldErrors.values.first.first;
    }
    return message;
  }

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

      return ApiException(message: message, fieldErrors: fieldErrors, statusCode: statusCode, code: data['code']?.toString());
    }

    return ApiException(message: 'Something went wrong. Please try again.', statusCode: statusCode);
  }
}
