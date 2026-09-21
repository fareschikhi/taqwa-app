import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one secure store the app keeps its session in.
///
/// [AndroidOptions.resetOnError] is what stops a damaged keystore from
/// locking a user out for good. An entry encrypted under a key Android has
/// since discarded — after an app update, a reinstall, or a restore from
/// backup — throws on every read until something clears it, and the default
/// is to keep throwing. Everything kept here is a session the user can simply
/// make again, so dropping it costs them one sign-in; keeping it costs them
/// the app.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
);
