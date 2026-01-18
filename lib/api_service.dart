import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      debugPrint('🔄 กำลังเรียก API: $baseUrl/login');
      debugPrint('📧 Username: $username');
      
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

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // โบ's API คืน { "message": "เข้าสู่ระบบสำเร็จ!", "user": {...} }
        // รองรับทั้งภาษาไทยและอังกฤษ
        if (data['user'] != null) {
          debugPrint('✅ Login สำเร็จ!');
          currentUser = data['user']; // Store user data globally
          return data['user'];
        }
      }
      // 401 = Invalid username or password
      debugPrint('❌ Login ไม่สำเร็จ');
      return null;
    } catch (e) {
      debugPrint('🚨 Login error: $e');
      return null;
    }
  }

  // ดึงข้อมูล assets ทั้งหมดจาก MySQL
  Future<List<Map<String, dynamic>>> getAssets() async {
    try {
      debugPrint('🔄 กำลังเรียก API: $baseUrl/assets');
      final response = await http.get(
        Uri.parse('$baseUrl/assets'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Get assets error: $e');
      return [];
    }
  }

  // ดึงข้อมูล assets ตาม location_id (ใช้ Endpoint ใหม่ /api/assets/room/:id)
  Future<List<Map<String, dynamic>>> getAssetsByLocation(int locationId) async {
    try {
      final String urlString = '$baseUrl/assets/room/$locationId';
      debugPrint('🔄 กำลังดึงครุภัณฑ์ในห้อง ID: $locationId');
      debugPrint('🔗 Endpoint: $urlString');
      
      final response = await http.get(
        Uri.parse(urlString),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        debugPrint('❌ ไม่พบข้อมูล หรือ Server Error (${response.statusCode})');
        return [];
      }
    } catch (e) {
      debugPrint('🚨 Get assets by location error: $e');
      return [];
    }
  }

  // เพิ่มครุภัณฑ์ใหม่ (Asset)
  Future<Map<String, dynamic>> addAsset(Map<String, dynamic> assetData) async {
    try {
      debugPrint('🔄 กำลังเพิ่มครุภัณฑ์ใหม่: ${assetData['asset_id']}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/assets'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'asset_id': assetData['asset_id'],
          'asset_type': assetData['type'], // App uses 'type', Backend uses 'asset_type'
          'brand_model': assetData['brand_model'],
          'location_id': assetData['location_id'],
          'status': assetData['status'],
          'checker_name': assetData['inspectorName'], // App uses 'inspectorName'
          'image_url': (assetData['images'] != null && (assetData['images'] as List).isNotEmpty) 
              ? assetData['images'][0] 
              : '', // Backend uses single 'image_url'
        }),
      );

      debugPrint('📡 Add Asset Status: ${response.statusCode}');
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'เพิ่มสำเร็จ'};
      }
      return {'success': false, 'message': data['message'] ?? 'เพิ่มไม่สำเร็จ'};
    } catch (e) {
      debugPrint('🚨 Add asset error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  // แก้ไขครุภัณฑ์ (Asset)
  // Backend ต้องการครบทุก field: asset_id, asset_type, brand_model, location_id, status, checker_name, image_url
  Future<Map<String, dynamic>> updateAsset(String id, Map<String, dynamic> assetData) async {
    try {
      debugPrint('🔄 กำลังแก้ไขครุภัณฑ์ ID (Database): $id');
      
      final response = await http.put(
        Uri.parse('$baseUrl/assets/$id'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'asset_id': assetData['asset_id'],
          'asset_type': assetData['type'],
          'brand_model': assetData['brand_model'],
          'location_id': assetData['location_id'],
          'status': assetData['status'],
          'checker_name': assetData['inspectorName'],
          'image_url': (assetData['images'] != null && (assetData['images'] as List).isNotEmpty) 
              ? assetData['images'][0] 
              : (assetData['image_url'] ?? ''), // Fallback
        }),
      );

      debugPrint('📡 Update Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'แก้ไขสำเร็จ'};
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'ไม่พบ API (404)'};
      } else if (response.statusCode == 500) {
        return {'success': false, 'message': 'Server Error (500)'};
      }
      return {'success': false, 'message': 'แก้ไขไม่สำเร็จ (${response.statusCode})'};
      
    } catch (e) {
      debugPrint('🚨 Update asset error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  // ลบครุภัณฑ์
  Future<Map<String, dynamic>> deleteAsset(String id) async {
    try {
      debugPrint('� กำลังลบครุภัณฑ์ ID: $id');
      final response = await http.delete(
        Uri.parse('$baseUrl/assets/$id'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'ลบสำเร็จ'};
      }
      return {'success': false, 'message': 'ลบไม่สำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  // ดึงข้อมูล Locations (ห้อง/ชั้น) จาก MySQL
  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      debugPrint('🔄 กำลังเรียก API: $baseUrl/locations');
      final response = await http.get(
        Uri.parse('$baseUrl/locations'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      // debugPrint('📄 Response Body: ${response.body}'); // อาจจะเยอะ comment ไว้ก่อน

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Get locations error: $e');
      return [];
    }
  }
  // เพิ่มห้องใหม่ (Location)
  // return: { success: bool, location_id: int?, message: String }
  Future<Map<String, dynamic>> addLocation(int floor, String roomName) async {
    try {
      debugPrint('🔄 กำลังเพิ่มห้อง: ชั้น $floor, ห้อง $roomName');
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

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');
      
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ เพิ่มห้องสำเร็จ');
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
      debugPrint('🚨 Add location error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ'};
    }
  }

  // ลบห้อง (Location)
  // return: { success: bool, message: String }
  Future<Map<String, dynamic>> deleteLocation(int locationId) async {
    try {
      debugPrint('🔄 กำลังลบห้อง ID: $locationId');
      // API ของโบใช้ DELETE /api/locations/:id
      final response = await http.delete(
        Uri.parse('$baseUrl/locations/$locationId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');
      
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ ลบห้องสำเร็จ');
        return {'success': true, 'message': 'ลบห้องสำเร็จ'};
      } else if (response.statusCode == 400) {
        // กรณีลบไม่ได้เพราะมีครุภัณฑ์
        return {'success': false, 'message': data['message'] ?? 'ไม่สามารถลบห้องได้'};
      }
      
      debugPrint('❌ ลบห้องไม่สำเร็จ: ${response.body}');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการลบห้อง'};
    } catch (e) {
      debugPrint('🚨 Delete location error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  // แก้ไขห้อง (Location) - รองรับแก้ชื่อห้อง หรือแก้ชั้น (API Update)
  Future<Map<String, dynamic>> updateRoomLocation(int locationId, {String? roomName, String? floor}) async {
    try {
      debugPrint('🔄 กำลังแก้ไขห้อง ID: $locationId');
      
      Map<String, dynamic> body = {};
      if (roomName != null) body['room_name'] = roomName;
      if (floor != null) body['floor'] = floor;

      final response = await http.put(
        Uri.parse('$baseUrl/locations/$locationId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');
      
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ แก้ไขสำเร็จ');
        return {'success': true, 'message': 'แก้ไขสำเร็จ'};
      }
      
      debugPrint('❌ แก้ไขไม่สำเร็จ: ${response.body}');
      return {'success': false, 'message': data['message'] ?? 'แก้ไขไม่สำเร็จ'};
    } catch (e) {
      debugPrint('🚨 Update location error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }



  // แจ้งปัญหา (Report Problem) -> Auto update status to 'ชำรุด'
  Future<Map<String, dynamic>> reportProblem(String assetId, String reporterName, String issueDetail) async {
    try {
      debugPrint('🔄 กำลังส่งรายงานแจ้งปัญหา: $assetId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'asset_id': assetId,
          'reporter_name': reporterName,
          'issue_detail': issueDetail,
        }),
      );

      debugPrint('📡 Report Status: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');
      
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'แจ้งปัญหาเรียบร้อยแล้ว'};
      }
      return {'success': false, 'message': data['message'] ?? 'แจ้งปัญหาไม่สำเร็จ'};
    } catch (e) {
      debugPrint('🚨 Report problem error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  // ดึงข้อมูลรายงานทั้งหมด (Reports)
  Future<List<Map<String, dynamic>>> getReports() async {
    try {
      debugPrint('🔄 กำลังเรียก API: $baseUrl/reports');
      final response = await http.get(
        Uri.parse('$baseUrl/reports'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Reports Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Get reports error: $e');
      return [];
    }
  }

  Future<dynamic> verifyPassword(String text) async {}
}
