import '../models/auth_models.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;

  Future<AuthUser> signInAnonymously();
  Future<AuthUser> signInWithEmailPassword({required String email, required String password});
  Future<AuthUser> signUpWithEmailPassword({required String email, required String password});
  Future<AuthUser> upgradeAnonymousAccount({required String email, required String password});
  Future<void> signOut();
}
