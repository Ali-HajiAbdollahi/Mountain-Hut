import '../../../../core/network/mountain_hut_api.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._api);

  final MountainHutApi _api;

  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    return _api.login(email, password);
  }

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    return _api.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
    );
  }
}
