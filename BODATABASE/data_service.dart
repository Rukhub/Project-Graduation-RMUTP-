import 'package:http/http.dart' as http;
import 'dart:convert';

class DataService {
  // 1. Singleton Pattern (แบบที่รักเคยทำไว้)
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // 2. ลิงก์ Ngrok ของโบ (ย้ำโบ: ถ้าเปิดใหม่ต้องมาแก้เลขตรงนี้!)
  static const String baseUrl = 'https://engrainedly-uredial-chloe.ngrok-free.dev/api';

  // ---------------------------------------------------------
  // ส่วนที่ 1: ฟังก์ชันเชื่อมต่อกับฐานข้อมูลของโบ (MySQL)
  // ---------------------------------------------------------

  // ฟังก์ชันสมัครสมาชิก
  Future<bool> register(String username, String password, String fullname) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'fullname': fullname,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ฟังก์ชันเข้าสู่ระบบ
  Future<Map<String, dynamic>?> login(String username, String password) async {
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
      return null;
    }
  }

  // ฟังก์ชันดึงข้อมูลครุภัณฑ์จากฐานข้อมูลโบ (ใช้แทนข้อมูลจำลอง)
  Future<List<dynamic>> fetchAssetsFromBo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/assets'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------
  // ส่วนที่ 2: ข้อมูลจำลองเดิมของรัก (เก็บไว้ใช้จัดการห้อง)
  // ---------------------------------------------------------

  final Map<int, List<String>> floorRooms = {
    1: ['Room 1951', 'Room 1952', 'Room 1953', 'Room 1954', 'Room 1955', 'Room 1956', 'Room 1957', 'Room 1958'],
    3: ['Room 3001', 'Room 3002'],
    5: ['Room 5001', 'Room 5002', 'Room 5003'],
  };

  // ดึงข้อมูลห้อง (ดึงจาก List ด้านบน)
  List<String> getRoomsInFloor(int floor) {
    return floorRooms[floor] ?? [];
  }
}
