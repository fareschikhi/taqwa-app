import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/providers/chat_unread_provider.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/data/repositories/chat_repository.dart';

class _FixedAuth extends AuthNotifier {
  _FixedAuth(this.user);
  final UserModel user;

  @override
  AuthState build() => AuthState(user: user, isAuthenticated: true);
}

class _FakeRepo extends ChatRepository {
  _FakeRepo(this.count, {this.fails = false});
  final int count;
  final bool fails;
  final calls = <bool>[];

  @override
  Future<int> unread({required bool staff}) async {
    calls.add(staff);
    if (fails) throw Exception('offline');
    return count;
  }
}

ProviderContainer _container(UserModel user, _FakeRepo repo) {
  final c = ProviderContainer(
    overrides: [
      authProvider.overrideWith(() => _FixedAuth(user)),
      chatRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

UserModel _user(UserRole role, {bool canChat = false}) =>
    UserModel(id: 1, fullName: 'x', role: role, canChat: canChat);

void main() {
  test('a parent counts staff messages', () async {
    final repo = _FakeRepo(3);
    final c = _container(_user(UserRole.parent), repo);

    await c.read(chatUnreadProvider.notifier).refresh();

    expect(c.read(chatUnreadProvider), 3);
    expect(repo.calls, [false]);
  });

  test('an admin counts as staff', () async {
    final repo = _FakeRepo(5);
    final c = _container(_user(UserRole.admin), repo);

    await c.read(chatUnreadProvider.notifier).refresh();

    expect(c.read(chatUnreadProvider), 5);
    expect(repo.calls, [true]);
  });

  test('a manager without chat gets 0 without asking the server', () async {
    final repo = _FakeRepo(5);
    final c = _container(_user(UserRole.manager), repo);

    await c.read(chatUnreadProvider.notifier).refresh();

    expect(c.read(chatUnreadProvider), 0);
    expect(repo.calls, isEmpty);
  });

  test('a failed refresh keeps the last count', () async {
    final failing = _FakeRepo(0, fails: true);
    final c = _container(_user(UserRole.parent), failing);
    c.read(chatUnreadProvider.notifier).state = 4;
    await c.read(chatUnreadProvider.notifier).refresh();

    expect(c.read(chatUnreadProvider), 4);
  });
}
