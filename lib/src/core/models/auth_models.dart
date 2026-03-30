enum AccountTier { guest, registered }

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.isAnonymous,
    this.email,
  });

  final String uid;
  final bool isAnonymous;
  final String? email;

  AccountTier get tier => isAnonymous ? AccountTier.guest : AccountTier.registered;
}
