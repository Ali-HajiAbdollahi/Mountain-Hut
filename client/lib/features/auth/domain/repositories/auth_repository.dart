abstract interface class AuthRepository {
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  });

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> requestPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  });
}
