import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';

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
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = DioClient.instance;

  @override
  AuthState build() {
    Future.microtask(() => checkAutoLogin());
    return AuthState();
  }

  Future<void> checkAutoLogin() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final cachedUserJson = await _storage.read(key: 'cached_user');
        UserModel? cachedUser;
        if (cachedUserJson != null) {
          cachedUser = UserModel.fromJson(jsonDecode(cachedUserJson));
        }

        state = state.copyWith(
          user: cachedUser,
          isAuthenticated: true,
          isLoading: false,
        );

        // Fetch fresh profile in the background
        final response = await _dio.get('${ApiEndpoints.users}/me');
        final freshUser = UserModel.fromJson(response.data);
        await _storage.write(key: 'cached_user', value: jsonEncode(freshUser.toJson()));
        
        state = state.copyWith(user: freshUser);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final isEmail = identifier.contains('@');
      final payload = {
        if (isEmail) 'email': identifier else 'phone': identifier,
        'password': password,
      };

      final response = await _dio.post(ApiEndpoints.login, data: payload);
      final token = response.data['accessToken'];
      final user = UserModel.fromJson(response.data['user']);

      await _storage.write(key: 'jwt_token', value: token);
      await _storage.write(key: 'cached_user', value: jsonEncode(user.toJson()));

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );
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

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'cached_user');
    ref.invalidateSelf();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
