import 'package:http/http.dart' as http;
import 'dart:convert';

class DataService {
  // 1. ลิงก์ Ngrok ของโบ (ย้ำโบ: ถ้าเปิดใหม่ต้องแก้ที่นี่)
  static const String baseUrl = 'https://engrainedly-uredial-chloe.ngrok-free.dev/api';

  // 2. ฟังก์ชัน Login แบบ Static (แก้ Error undefined_method)
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  // 3. ข้อมูลจำลองเดิม (คงไว้ตามที่รักทำ)
  final Map<int, List<String>> floorRooms = {
    1: ['Room 1951', 'Room 1952', 'Room 1953'],
    3: ['Room 3001'],
  };
}
