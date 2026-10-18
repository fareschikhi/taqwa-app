import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:taqwa/core/storage/secure_storage.dart';
import 'package:taqwa/core/utils/session_expiry.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/data/repositories/auth_repository_impl.dart';
import 'package:taqwa/features/data/repositories/device_repository.dart';
import 'package:taqwa/features/data/datasources/user_remote_datasource.dart';

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;
  final bool isAuthenticated;

  AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final FlutterSecureStorage _storage = appSecureStorage;
  final AuthRepository _authRepository = AuthRepository();
  final UserRemoteDatasource _userDatasource = UserRemoteDatasource();
  final DeviceRepository _deviceRepository = DeviceRepository();

  /// Asks for notification permission and hands the device's token to the API,
  /// so notifications written for this user can be pushed to this phone.
  ///
  /// Android 13 and up treat notifications as a runtime permission, so this is
  /// a real prompt the parent can refuse. Refusing costs them only the tray
  /// notification — the notifications tab reads the same rows either way.
  Future<void> _registerDevice() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) await _deviceRepository.register(token);

      // FCM rotates tokens on its own schedule, and a stale one simply stops
      // being delivered to. Without this the phone goes quiet weeks later
      // with nothing in the logs to say why.
      messaging.onTokenRefresh.listen(_deviceRepository.register);
    } catch (_) {
      // Push is an enhancement to a feature that already works. Failing to
      // arrange it must not fail the sign-in that triggered it.
    }
  }

  @override
  AuthState build() {
    Future.microtask(() => checkAutoLogin());
    // Loading from the first frame, not from when checkAutoLogin gets its
    // turn: a returning user would otherwise be shown the login form for the
    // microtask it takes to read their token back.
    return AuthState(isLoading: true);
  }

  Future<void> checkAutoLogin() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (!ref.mounted) return;
      if (token != null) {
        final cachedUserJson = await _storage.read(key: 'cached_user');
        if (!ref.mounted) return;
        UserModel? cachedUser;
        if (cachedUserJson != null) {
          cachedUser = UserModel.fromJson(jsonDecode(cachedUserJson));
        }

        state = state.copyWith(
          user: cachedUser,
          isAuthenticated: true,
          isLoading: false,
        );

        // A returning user never passes through login(), and their token
        // still has to be current. Not awaited: the permission prompt must
        // not hold up the screen behind it.
        unawaited(_registerDevice());

        // Fetch fresh profile in the background
        final freshUser = await _userDatasource.me();
        await _storage.write(
          key: 'cached_user',
          value: jsonEncode(freshUser.toJson()),
        );
        if (!ref.mounted) return;
        state = state.copyWith(user: freshUser);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on Object catch (e) {
      // Signing out invalidates this notifier, so a launch the user abandons
      // part-way leaves this running against a Ref that is already gone.
      if (!ref.mounted) return;
      // Only the server refusing the token means the session is over. Any
      // other failure — no signal, a sleeping server, a 500 — leaves the
      // cached session in place so the app still opens on what it has.
      if (isRejectedSession(e)) {
        await _storage.delete(key: 'jwt_token');
        await _storage.delete(key: 'cached_user');
        if (!ref.mounted) return;
        state = AuthState();
        return;
      }
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> login(String identifier, String password) async {
    // Only the stale error is cleared, never isLoading: that flag is how
    // AuthGate says "still restoring a stored session", and raising it here
    // swapped the login form out for the startup spinner mid-request. The
    // form's State went with it, so the refusal came back to a page that was
    // already gone — no reason shown, and the identifier the user had typed
    // lost along with the old controllers. The button runs its own spinner.
    state = state.copyWith(errorMessage: null);
    try {
      final result = await _authRepository.login(
        identifier: identifier,
        password: password,
      );
      final user = result.user;

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );

      // Not awaited: the permission prompt would otherwise sit in front of a
      // login that has already succeeded.
      unawaited(_registerDevice());

      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.error?.toString() ?? 'فشل تسجيل الدخول',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'حدث خطأ غير متوقع',
      );
      return false;
    }
  }

  /// Saves the signed-in user's own details and keeps both the in-memory
  /// state and the cached copy in step, so the change shows immediately and
  /// survives a restart. Throws on failure so the caller can show why.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String email,
  }) async {
    final updated = await _userDatasource.updateMe(
      fullName: fullName,
      phone: phone,
      email: email,
    );
    await _storage.write(
      key: 'cached_user',
      value: jsonEncode(updated.toJson()),
    );
    state = state.copyWith(user: updated);
  }

  Future<void> logout() async {
    // Released before the token goes, since the request needs it. A shared
    // phone would otherwise keep delivering this parent's notifications to
    // whoever signs in next.
    if (!kIsWeb) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _deviceRepository.unregister(token);
      } catch (_) {
        // Signing out must succeed even with no network.
      }
    }

    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'cached_user');
    ref.invalidateSelf();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
