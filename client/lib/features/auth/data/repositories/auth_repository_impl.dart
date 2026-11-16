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

  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _api.requestPasswordReset(email);

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) {
    return _api.confirmPasswordReset(token: token, newPassword: newPassword);
  }
}
