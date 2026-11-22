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

  // True connection failure (no network reachable at all) — distinct from
  // .timeout() below, which used to show this exact same "check your
  // internet" text even when the connection was fine but a slow upload or
  // a slow server response just took too long. That collapsed two very
  // different situations into one misleading message.
  factory ApiException.network({bool urdu = false}) => ApiException(
        message: urdu
            ? 'رابطہ نہیں ہو سکا۔ اپنا انٹرنیٹ کنکشن چیک کریں۔'
            : 'Couldn\'t connect. Check your internet connection.',
      );

  factory ApiException.timeout({bool urdu = false}) => ApiException(
        message: urdu
            ? 'جواب آنے میں معمول سے زیادہ وقت لگ رہا ہے — ہو سکتا ہے آپ کا کنکشن سست ہو یا سرور مصروف ہو۔ براہ کرم دوبارہ کوشش کریں۔'
            : 'This is taking longer than expected — your connection may be slow, or our server is busy. Please try again.',
      );

  // The fallback text here only fires when the server's own response has no
  // 'message' field at all (or isn't a Map) — a rarer path than .network()/
  // .timeout() above, but the same bug applied: it used to always be
  // English even on a device set to Urdu, since this bypassed the `urdu`
  // check those two already had.
  factory ApiException.fromResponseData(dynamic data, int? statusCode, {bool urdu = false}) {
    final fallback = urdu ? 'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔' : 'Something went wrong. Please try again.';

    if (data is Map) {
      final message = data['message']?.toString() ?? fallback;
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

    return ApiException(message: fallback, statusCode: statusCode);
  }
}
