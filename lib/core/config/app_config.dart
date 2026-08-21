// Points at production by default. Override for local testing with:
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
// (10.0.2.2 is the Android emulator's alias for the host machine's localhost.)
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sallaamti.com/api/v1',
  );
}
