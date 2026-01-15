import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Ngrok URL จากเพื่อน
  static const String baseUrl = 'https://engrainedly-uredial-chloe.ngrok-free.dev/api';

  // Login method - ตรวจสอบ username/password จาก MySQL ผ่าน Node.js API ของโบ
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      print('🔄 กำลังเรียก API: $baseUrl/login');
      print('📧 Username: $username');
      
      final response = await http.post(
        Uri.parse('$baseUrl/login'),  // Node.js ใช้ /login ไม่ใช่ /login.php
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',  // สำหรับ ngrok
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // โบ's API คืน { "message": "เข้าสู่ระบบสำเร็จ!", "user": {...} }
        // รองรับทั้งภาษาไทยและอังกฤษ
        if (data['user'] != null) {
          print('✅ Login สำเร็จ!');
          return data['user'];
        }
      }
      // 401 = Invalid username or password
      print('❌ Login ไม่สำเร็จ');
      return null;
    } catch (e) {
      print('🚨 Login error: $e');
      return null;
    }
  }

  // ดึงข้อมูล assets ทั้งหมดจาก MySQL
  Future<List<Map<String, dynamic>>> getAssets() async {
    try {
      print('🔄 กำลังเรียก API: $baseUrl/assets');
      final response = await http.get(
        Uri.parse('$baseUrl/assets'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      print('🚨 Get assets error: $e');
      return [];
    }
  }
}
