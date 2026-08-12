class ApiEndpoints {
  // Production API on Render. A phone needs a public address, so a LAN IP only
  // works while the device sits on the same network as the dev machine.
  //
  // For local development, swap in one of these:
  //   'http://10.0.2.2:3000/api'        Android emulator
  //   'http://localhost:3000/api'       physical device via `adb reverse tcp:3000 tcp:3000`
  //   'http://192.168.100.76:3000/api'  physical device on the same WiFi
  static const String baseUrl = 'https://taqwa-api-txbq.onrender.com/api';
  static const String login = '/auth/login';
  static const String users = '/users';
  static const String teachers = '/teachers';
  static const String students = '/students';
  static const String parents = '/parents';
  static const String halaqas = '/halaqas';
  static const String attendance = '/attendance';
  static const String memorization = '/memorization';
  static const String evaluations = '/evaluations';
  static const String notifications = '/notifications';
  static const String managers = '/managers';
  static const String absenceJustifications = '/absence-justifications';
  static const String studentNotes = '/student-notes';
  static const String uploads = '/uploads';
}
