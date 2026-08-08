class ApiEndpoints {
  // Use 'http://10.0.2.2:3000/api' for Android emulator
  // Use 'http://localhost:3000/api' for physical device (with adb reverse tcp:3000 tcp:3000)
  // Use 'http://10.172.59.43:3000/api' for physical device on local network (no adb needed)
  static const String baseUrl = 'http://192.168.100.76:3000/api';
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
