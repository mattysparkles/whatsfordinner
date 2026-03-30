import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/models/auth_models.dart';
import '../../core/repositories/auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository() : _controller = StreamController<AuthUser?>.broadcast();

  final StreamController<AuthUser?> _controller;
  static const _uuid = Uuid();
  AuthUser? _current;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInAnonymously() async {
    _current = AuthUser(uid: 'guest-${_uuid.v4()}', isAnonymous: true);
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<AuthUser> signInWithEmailPassword({required String email, required String password}) async {
    _current = AuthUser(uid: 'local-${email.hashCode}', isAnonymous: false, email: email);
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<AuthUser> signUpWithEmailPassword({required String email, required String password}) async {
    return signInWithEmailPassword(email: email, password: password);
  }

  @override
  Future<AuthUser> upgradeAnonymousAccount({required String email, required String password}) async {
    return signInWithEmailPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }
}
