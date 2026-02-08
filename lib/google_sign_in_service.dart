import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleSignInService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    hostedDomain: 'rmutp.ac.th',
    serverClientId:
        '184587611261-becig1ab3ajnjuf94bsuh7p2b0jplh4e.apps.googleusercontent.com',
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ล็อกอินด้วย Google และคืนค่า Firebase User (เฉพาะ @rmutp.ac.th)
  Future<User?> signInWithGoogle() async {
    try {
      // Force account picker by signing out first
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) return null;

      // ตรวจสอบอีเมลอีกครั้งเพื่อความปลอดภัย
      if (!account.email.endsWith('@rmutp.ac.th')) {
        debugPrint('Email domain not allowed: ${account.email}');
        await _googleSignIn.signOut();
        return null;
      }

      // ⭐ Sign in to Firebase with Google Credential
      final GoogleSignInAuthentication googleAuth =
          await account.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (error) {
      debugPrint('Error signing in with Google: $error');
      return null;
    }
  }

  /// ออกจากระบบ
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// เช็คว่ามีการล็อกอินอยู่หรือไม่
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// ดึงข้อมูลผู้ใช้ปัจจุบัน
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
