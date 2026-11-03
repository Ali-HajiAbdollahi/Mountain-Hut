abstract interface class AuthRepository {
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  });

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  });
}
