import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Ngrok URL จากเพื่อน
  static const String baseUrl = 'https://engrainedly-uredial-chloe.ngrok-free.dev/api';

  // เก็บข้อมูลผู้ใช้ที่ล็อกอิน (currentUser)
  Map<String, dynamic>? currentUser;

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

  // ดึงข้อมูล Locations (ห้อง/ชั้น) จาก MySQL
  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      print('🔄 กำลังเรียก API: $baseUrl/locations');
      final response = await http.get(
        Uri.parse('$baseUrl/locations'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      // print('📄 Response Body: ${response.body}'); // อาจจะเยอะ comment ไว้ก่อน

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      print('🚨 Get locations error: $e');
      return [];
    }
  }
  // เพิ่มห้องใหม่ (Location)
  // return: { success: bool, location_id: int?, message: String }
  Future<Map<String, dynamic>> addLocation(int floor, String roomName) async {
    try {
      print('🔄 กำลังเพิ่มห้อง: ชั้น $floor, ห้อง $roomName');
      final response = await http.post(
        Uri.parse('$baseUrl/locations'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'floor': 'ชั้น $floor', // ส่งแบบ string ตาม Database
          'room_name': roomName,
        }),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');
      
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ เพิ่มห้องสำเร็จ');
        // คาดหวังว่า API จะส่ง { "message": "...", "location_id": 123 } หรือ "id"
        // ถ้าไม่มี id อาจจะต้อง reload อย่างเดียว แต่เราจะพยายามหา
        int? newId = data['location_id'] ?? data['id'] ?? data['insertId'];
        return {
          'success': true, 
          'message': 'เพิ่มห้องสำเร็จ', 
          'location_id': newId 
        };
      }
      return {'success': false, 'message': data['message'] ?? 'เพิ่มห้องไม่สำเร็จ'};
    } catch (e) {
      print('🚨 Add location error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ'};
    }
  }

  // ลบห้อง (Location)
  // return: { success: bool, message: String }
  Future<Map<String, dynamic>> deleteLocation(int locationId) async {
    try {
      print('🔄 กำลังลบห้อง ID: $locationId');
      // API ของโบใช้ DELETE /api/locations/:id
      final response = await http.delete(
        Uri.parse('$baseUrl/locations/$locationId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');
      
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ ลบห้องสำเร็จ');
        return {'success': true, 'message': 'ลบห้องสำเร็จ'};
      } else if (response.statusCode == 400) {
        // กรณีลบไม่ได้เพราะมีครุภัณฑ์
        return {'success': false, 'message': data['message'] ?? 'ไม่สามารถลบห้องได้'};
      }
      
      print('❌ ลบห้องไม่สำเร็จ: ${response.body}');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการลบห้อง'};
    } catch (e) {
      print('🚨 Delete location error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }
}
