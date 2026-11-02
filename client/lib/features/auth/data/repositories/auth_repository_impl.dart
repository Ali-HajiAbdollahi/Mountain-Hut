import '../../../../core/network/mountain_hut_api.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._api);

  final MountainHutApi _api;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _api.login(email, password);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _api.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
    );
  }
}
