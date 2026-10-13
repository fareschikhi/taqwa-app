class ApiEndpoints {
  /// Where the app talks to the API. Defaults to the self-hosted production
  /// server, published through Tailscale Funnel: the ISP refuses every
  /// incoming connection to that line, so port forwarding cannot reach it,
  /// while Funnel only needs the server to connect out. It is
  /// overridden at build time so pointing at a local backend never means
  /// editing this file (and never means accidentally committing a localhost URL):
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
  ///
  /// Which address depends on how the app reaches the dev machine:
  ///   http://10.0.2.2:3000/api        Android emulator (its alias for the host)
  ///   http://localhost:3000/api       USB device, after `adb reverse tcp:3000 tcp:3000`
  ///   `http://<dev-machine-LAN-IP>:3000/api`  device on the same WiFi
  ///
  /// A phone needs a public address, so a LAN IP only works while the device
  /// sits on the same network as the dev machine.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fares.taile6d404.ts.net/api',
  );
  static const String login = '/auth/login';
  static const String changePassword = '/auth/password';
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
  static const String halaqaAnnouncements = '/halaqa-announcements';
  static const String uploads = '/uploads';
  static const String devices = '/devices';

  /// Turns a stored image reference into a URL the app can load.
  ///
  /// The API stores uploads as a path relative to [baseUrl] (`media/…`), so a
  /// move to another host never breaks them. Full URLs, such as avatars
  /// uploaded before images moved off Cloudinary, pass through unchanged.
  static String mediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl/$path';
  }
}
