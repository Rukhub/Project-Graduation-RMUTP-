import 'package:flutter/material.dart';
import 'menu.dart'; 
import 'data_service.dart'; // <-- เช็คว่ารักวางไฟล์ไว้ใน lib โฟลเดอร์เดียวกันนะ

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage());
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ตัวรับค่าจากช่องพิมพ์
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9A2C2C),
      body: Column(
        children: [
          const SizedBox(height: 100),
          Image.network('https://eng.rmutp.ac.th/web2558/wp-content/uploads/2024/03/%E0%B9%80%E0%B8%9F%E0%B8%B7%E0%B8%AD%E0%B8%87%E0%B9%81%E0%B8%94%E0%B8%872-350x350.png', height: 200),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(50))),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('ระบบจัดเก็บข้อมูลครุภัณฑ์', style: TextStyle(color: Color(0xFF9A2C2C), fontSize: 25, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _usernameController, // ใส่ตัวรับค่า
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.person), hintText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController, // ใส่ตัวรับค่า
                      obscureText: true,
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.lock), hintText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
                    ),
                    const SizedBox(height: 50),
                    SizedBox(
                      width: double.infinity, height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9A2C2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        onPressed: () async {
                          // เรียกใช้ DataService ที่เราแก้เป็น static
                          final result = await DataService.login(_usernameController.text, _passwordController.text);
                          
                          if (!mounted) return; // แก้ Error BuildContext

                          if (result != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MenuScreen()));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง')));
                          }
                        },
                        child: const Text('Login', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
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
}
