abstract interface class AuthRepository {
  Future<void> signIn({
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
