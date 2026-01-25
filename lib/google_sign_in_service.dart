import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleSignInService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // จำกัดเฉพาะอีเมล @rmutp.ac.th เท่านั้น
    hostedDomain: 'rmutp.ac.th',
    // ⚠️ ต้องไปขอ Web Client ID จาก Google Cloud Console
    // หรือใช้ค่านี้ชั่วคราว (ให้โบแทนด้วย Web Client ID จริง)
    // serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
  );

  /// ล็อกอินด้วย Google และคืนค่า GoogleSignInAccount (เฉพาะ @rmutp.ac.th)
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      // ตรวจสอบอีเมลอีกครั้งเพื่อความปลอดภัย
      if (account != null && !account.email.endsWith('@rmutp.ac.th')) {
        if (kDebugMode) {
          print('Email domain not allowed: ${account.email}');
        }
        await _googleSignIn.signOut();
        return null;
      }

      return account;
    } catch (error) {
      if (kDebugMode) {
        print('Error signing in with Google: $error');
      }
      return null;
    }
  }

  /// ออกจากระบบ Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// เช็คว่ามีการล็อกอินอยู่หรือไม่
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// ดึงข้อมูลผู้ใช้ปัจจุบัน
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
