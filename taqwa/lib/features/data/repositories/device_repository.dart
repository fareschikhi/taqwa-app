import '../datasources/device_remote_datasource.dart';

class DeviceRepository {
  final _ds = DeviceRemoteDatasource();

  Future<void> register(String token) => _ds.register(token);
  Future<void> unregister(String token) => _ds.unregister(token);
}
