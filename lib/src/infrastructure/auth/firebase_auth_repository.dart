import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/auth_models.dart';
import '../../core/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map(_mapUser);
  }

  @override
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Future<AuthUser> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return _mapRequiredUser(credential.user);
  }

  @override
  Future<AuthUser> signInWithEmailPassword({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _mapRequiredUser(credential.user);
  }

  @override
  Future<AuthUser> signUpWithEmailPassword({required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return _mapRequiredUser(credential.user);
  }

  @override
  Future<AuthUser> upgradeAnonymousAccount({required String email, required String password}) async {
    final current = _auth.currentUser;
    if (current == null) {
      return signUpWithEmailPassword(email: email, password: password);
    }
    if (!current.isAnonymous) return _mapRequiredUser(current);
    final credential = EmailAuthProvider.credential(email: email, password: password);
    final upgraded = await current.linkWithCredential(credential);
    return _mapRequiredUser(upgraded.user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUser(uid: user.uid, isAnonymous: user.isAnonymous, email: user.email);
  }

  AuthUser _mapRequiredUser(User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw StateError('FirebaseAuth operation completed without a user.');
    }
    return mapped;
  }
}
