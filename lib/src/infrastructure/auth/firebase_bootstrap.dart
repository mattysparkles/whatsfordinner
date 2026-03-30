import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  static Future<bool> initialize({required bool useEmulator}) async {
    try {
      await Firebase.initializeApp();
      if (useEmulator) {
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
