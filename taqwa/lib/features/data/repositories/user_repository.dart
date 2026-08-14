import 'package:taqwa/features/data/datasources/user_remote_datasource.dart';

class UserRepository {
  final _ds = UserRemoteDatasource();

  Future<void> setActive(int userId, bool isActive) =>
      _ds.setActive(userId, isActive);
}
