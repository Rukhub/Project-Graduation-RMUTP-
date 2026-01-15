import 'package:flutter/material.dart';
import 'menu.dart'; 
import 'data_service.dart'; // <-- ต้องมั่นใจว่ารักมีไฟล์นี้และ import มาแล้ว

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

class LoginPage extends StatefulWidget { // เปลี่ยนเป็น StatefulWidget เพื่อจัดการค่าที่พิมพ์
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. เพิ่มตัวรับข้อมูลจากช่องพิมพ์
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
                      style: TextStyle(color: Color(0xFF9A2C2C), fontSize: 25, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),
                    // 2. ใส่ Controller ในช่อง Username
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person),
                        hintText: 'Username',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 3. ใส่ Controller ในช่อง Password
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        hintText: 'Password',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9A2C2C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () async {
                          // --- 🚀 ส่วนสำคัญ: ส่งข้อมูลไปเช็คที่เครื่องโบ ---
                          final result = await DataService().login(
                            _usernameController.text,
                            _passwordController.text,
                          );

                          if (result != null) {
                            // ถ้า Login สำเร็จ ให้ไปหน้า Menu
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MenuScreen()),
                            );
                          } else {
                            // ถ้า Login ไม่สำเร็จ ให้ขึ้นเตือน
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Username หรือ Password ไม่ถูกต้อง!')),
                            );
                          }
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
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
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: Image.network(
                              'https://cdn-icons-png.flaticon.com/512/2991/2991148.png', // เปลี่ยนเป็นรูป Google จริงๆ
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Login with your others account',
                          style: TextStyle(color: Colors.grey),
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
}
