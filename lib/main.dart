import 'package:flutter/material.dart';
import 'menu.dart';
import 'api_service.dart';
import 'google_sign_in_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // ตรวจสอบว่ากรอกข้อมูลครบหรือไม่
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอก Username และ Password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // เรียกใช้ ApiService เพื่อ Login
    final user = await ApiService().login(username, password);

    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      // ตรวจสอบสถานะการอนุมัติ
      bool isApproved = (user['is_approved'] == 1);

      if (!isApproved) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.hourglass_empty, color: Colors.orange.shade700),
                  const SizedBox(width: 10),
                  const Text(
                    'รอการอนุมัติ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                'บัญชีนี้รอการอนุมัติจากแอดมินนะ\nโปรดติดต่อผู้ดูแลระบบ',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ตกลง',
                    style: TextStyle(
                      color: Color(0xFF9A2C2C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return; // หยุดการทำงาน ไม่ไปต่อ
      }

      // Login สำเร็จ และผ่านการอนุมัติ
      // บันทึกข้อมูลผู้ใช้
      ApiService().currentUser = user;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuScreen()),
        );
      }
    } else {
      // Login ไม่สำเร็จ
      setState(() {
        _errorMessage = 'Username หรือ Password ไม่ถูกต้อง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9A2C2C),
      body: Column(
        children: [
          const SizedBox(height: 100),
          Image.network(
            'https://eng.rmutp.ac.th/web2558/wp-content/uploads/2024/03/%E0%B9%80%E0%B8%9F%E0%B8%B7%E0%B8%AD%E0%B8%87%E0%B9%81%E0%B8%94%E0%B8%872-350x350.png',
            height: 200,
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'ระบบจัดเก็บข้อมูลครุภัณฑ์',
                      style: TextStyle(
                        color: Color(0xFF9A2C2C),
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // แสดง error message ถ้ามี
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person),
                        hintText: 'Username',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.shade600,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        hintText: 'Password',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Colors.grey.shade600,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 50),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9A2C2C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _handleLogin,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade400,
                            thickness: 1.2,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade400,
                            thickness: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google Button
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _handleGoogleLogin,
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white,
                                // Google Logo
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Google',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 40), // Spacing
                        // ThaID Button (Show only)
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('ThaID login coming soon!'),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white,
                                child: ClipOval(
                                  child: Image.network(
                                    'https://play-lh.googleusercontent.com/jg2lAQET3kV_-6fhPQ_TcDyDItUdDcO7euuUNcANIn78_XJUmCtFBJzEdP3nG4_e2kM=w240-h480-rw', // Existing ThaID Image
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ThaID',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Login with your others account',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => _handleBypassLogin(isAdmin: true),
                          icon: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Dev (Admin)',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: () => _handleBypassLogin(isAdmin: false),
                          icon: const Icon(Icons.person, color: Colors.green),
                          label: const Text(
                            'Dev (User)',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ล็อกอินด้วย Google Account (จำกัดเฉพาะ @rmutp.ac.th)
  void _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. เรียก Google Sign-In
      final googleAccount = await GoogleSignInService().signInWithGoogle();

      if (googleAccount == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ยกเลิกการล็อกอินด้วย Google';
        });
        return;
      }

      // 2. ส่งข้อมูลไปยัง Backend
      final result = await ApiService().googleLogin(
        googleId: googleAccount.id,
        email: googleAccount.email,
        displayName: googleAccount.displayName ?? 'Google User',
        photoUrl: googleAccount.photoUrl,
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        // กรณีที่ 1: มี Error Message จาก Backend (403)
        if (result['error'] == true) {
          setState(() {
            _errorMessage = result['message'] ?? 'เข้าใช้งานไม่ได้';
          });
          return;
        }

        // กรณีที่ 2: ลงทะเบียนใหม่สำเร็จ แต่ต้องรอ Admin อนุมัติ
        if (result['pending_approval'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result['message'] ?? 'กรุณารอแอดมินอนุมัติเข้าใช้งาน',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          // ออกจากระบบ Google เพราะยังเข้าใช้งานไม่ได้
          await GoogleSignInService().signOut();
          return;
        }

        // กรณีที่ 3: Login สำเร็จ (มี user object)
        if (result['user_id'] != null || result['email'] != null) {
          ApiService().currentUser = result;

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MenuScreen()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'ไม่สามารถเชื่อมต่อ Server ได้';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
      });
    }
  }

  void _handleBypassLogin({required bool isAdmin}) {
    // Mock User Data for testing without backend
    final mockUser = {
      'user_id': isAdmin ? 9999 : 8888,
      'username': isAdmin ? 'dev_admin' : 'dev_user',
      'fullname': isAdmin ? 'Developer Mode (Admin)' : 'Developer Mode (User)',
      'role': isAdmin ? 'admin' : 'user',
      'position': 'Developer',
      'is_approved': 1,
    };

    ApiService().currentUser = mockUser;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Entered Dev Mode as ${isAdmin ? 'Admin' : 'User'} (Offline)',
          ),
          backgroundColor: isAdmin ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MenuScreen()),
      );
    }
  }
}