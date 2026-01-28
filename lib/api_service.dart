import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Ngrok URL จากเพื่อน
  static const String baseUrl =
      'https://engrainedly-uredial-chloe.ngrok-free.dev/api';

  // เก็บข้อมูลผู้ใช้ที่ล็อกอิน (currentUser)
  Map<String, dynamic>? currentUser;

  // Cache สำหรับเก็บรายชื่อผู้ใช้ทั้งหมด (ID -> Name) เพื่อใช้แสดงผล
  static final Map<String, String> _allUsersCache = {};

  /// โหลดรายชื่อผู้ใช้ทั้งหมดมาเก็บใน Cache
  Future<void> loadAllUsersToCache() async {
    try {
      final users = await getAllUsersFromAPI();
      for (var u in users) {
        final id = u['user_id']?.toString() ?? u['id']?.toString();
        final name = u['fullname'] ?? u['username'];
        if (id != null && name != null) {
          _allUsersCache[id] = name;
        }
      }
      debugPrint('📦 Cached ${_allUsersCache.length} user names');
    } catch (e) {
      debugPrint('🚨 Error caching users: $e');
    }
  }

  // Helper สำหรับแปลง ID เป็นชื่อ
  String getUserName(dynamic idOrName) {
    if (idOrName == null) return 'ไม่ระบุ';
    final String s = idOrName.toString();

    // ถ้าไม่ใช่ตัวเลข (คือเป็นชื่อมาอยู่แล้ว) ให้คืนค่าเดิม
    if (int.tryParse(s) == null) return s;

    // ถ้าเป็น ID ให้เช็คใน Cache
    if (_allUsersCache.containsKey(s)) {
      return _allUsersCache[s]!;
    }

    // ถ้าเป็นตัวเราเอง
    final myId =
        currentUser?['user_id']?.toString() ?? currentUser?['id']?.toString();
    if (s == myId) {
      return currentUser?['fullname'] ?? currentUser?['username'] ?? s;
    }

    return 'ผู้ตรวจสอบ #$s';
  }

  // Login method - ตรวจสอบ username/password จาก MySQL ผ่าน Node.js API ของโบ
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      debugPrint('🔄 กำลังเรียก API: $baseUrl/login');
      debugPrint('📧 Username: $username');

      final response = await http.post(
        Uri.parse('$baseUrl/login'), // Node.js ใช้ /login ไม่ใช่ /login.php
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true', // สำหรับ ngrok
        },
        body: jsonEncode({'username': username, 'password': password}),
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

          // โหลดรายชื่อผู้ใช้ทั้งหมดมาเก็บไว้ใน Cache ทันทีที่ Login
          await loadAllUsersToCache();

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

  /// ล็อกอินด้วย Google Account (เฉพาะ @rmutp.ac.th)
  Future<Map<String, dynamic>?> googleLogin({
    required String googleId,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      debugPrint('🔄 กำลังล็อกอินด้วย Google: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'google_id': googleId,
          'email': email,
          'fullname': displayName,
          'photo_url': photoUrl,
        }),
      );

      debugPrint('📡 Google Login Status: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // กรณีที่ 1: Login สำเร็จ (มี user object)
        if (data['user'] != null) {
          debugPrint('✅ Google Login สำเร็จ!');
          currentUser = data['user'];

          // โหลดรายชื่อผู้ใช้ทั้งหมดมาเก็บไว้ใน Cache ทันทีที่ Login
          await loadAllUsersToCache();

          return data['user'];
        }

        // กรณีที่ 2: ลงทะเบียนใหม่สำเร็จ แต่ต้องรอ Approve (ไม่มี user object)
        if (data['user_id'] != null) {
          debugPrint('⏳ ลงทะเบียนสำเร็จ แต่ต้องรอ Admin อนุมัติ');
          return {
            'pending_approval': true,
            'message': data['message'] ?? 'กรุณารอแอดมินอนุมัติ',
          };
        }
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        debugPrint('❌ Error 403: ${data['message']}');

        // ส่ง error message กลับไปให้ UI แสดง
        return {
          'error': true,
          'message': data['message'] ?? 'เข้าใช้งานไม่ได้',
        };
      }

      debugPrint('❌ Google Login ไม่สำเร็จ');
      return null;
    } catch (e) {
      debugPrint('🚨 Google login error: $e');
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

  // ดึงข้อมูลครุภัณฑ์จาก asset_id (สำหรับ QR Code Scan)
  // รวม JOIN กับ Location เพื่อดึงชื่อห้องมาด้วย
  Future<Map<String, dynamic>?> getAssetById(String assetId) async {
    try {
      debugPrint('🔄 กำลังค้นหาครุภัณฑ์: $assetId');

      // ดึงครุภัณฑ์ทั้งหมด
      final assets = await getAssets();

      // หาครุภัณฑ์ที่ตรงกับ asset_id
      for (var asset in assets) {
        if (asset['asset_id'] == assetId) {
          debugPrint('✅ เจอครุภัณฑ์: ${asset['asset_id']}');
          debugPrint(
            '🧐 Asset Keys: ${asset.keys.toList()}',
          ); // ดู Keys ทั้งหมดที่มี
          if (asset['id'] == null) debugPrint('😱 NO ID FIELD FOUND!');

          // ดึงข้อมูล location มาเพิ่ม ถ้ามี location_id
          if (asset['location_id'] != null) {
            try {
              final locations = await getLocations();
              final locationId = asset['location_id'];

              // หา location ที่ตรงกัน
              final matchingLocation = locations.firstWhere(
                (loc) =>
                    loc['location_id'] == locationId || loc['id'] == locationId,
                orElse: () => {},
              );

              if (matchingLocation.isNotEmpty) {
                // เพิ่มข้อมูลห้องเข้าไปใน asset
                asset['location_name'] = matchingLocation['room_name'];
                asset['floor'] = matchingLocation['floor'];
                debugPrint(
                  '🏠 พบข้อมูลห้อง: ${matchingLocation['room_name']} ชั้น ${matchingLocation['floor']}',
                );
              } else {
                debugPrint('⚠️ ไม่พบข้อมูลห้องสำหรับ location_id: $locationId');
              }
            } catch (e) {
              debugPrint('⚠️ ไม่สามารถดึงข้อมูลห้องได้: $e');
            }
          }

          // แปลง asset_type เป็น type สำหรับ compatibility
          if (asset['asset_type'] != null && asset['type'] == null) {
            asset['type'] = asset['asset_type'];
          }

          return asset;
        }
      }

      debugPrint('❌ ไม่พบครุภัณฑ์ $assetId');
      return null;
    } catch (e) {
      debugPrint('🚨 Get asset by ID error: $e');
      return null;
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
          'asset_type':
              assetData['type'], // App uses 'type', Backend uses 'asset_type'
          'brand_model': assetData['brand_model'],
          'location_id': assetData['location_id'],
          'status': assetData['status'],
          'checker_name':
              assetData['inspectorName'], // App uses 'inspectorName'
          'image_url':
              // ✅ รองรับทั้ง 'image_url' (จาก krupan_room) และ 'images' (จาก add_equipment_quick)
              assetData['image_url']?.toString().isNotEmpty == true
              ? assetData['image_url']
              : (assetData['images'] != null &&
                    (assetData['images'] as List).isNotEmpty)
              ? assetData['images'][0]
              : null,
          'created_by': assetData['created_by'], // Add created_by
          // Note: Backend might ignore extra fields, so this is safe.
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
  Future<Map<String, dynamic>> updateAsset(
    String id,
    Map<String, dynamic> assetData,
  ) async {
    try {
      debugPrint('🔄 กำลังแก้ไขครุภัณฑ์ ID (Database): $id');

      final uri = Uri.parse('$baseUrl/assets/$id');
      debugPrint('🚀 Sending PUT Request to: $uri'); // Log URL จริงที่ยิงออกไป

      final response = await http.put(
        uri,
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
          'reporter_name': assetData['reporter_name'],
          'issue_detail': assetData['issue_detail'],
          'image_url':
              (assetData['images'] != null &&
                  (assetData['images'] as List).isNotEmpty)
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
      return {
        'success': false,
        'message': 'แก้ไขไม่สำเร็จ (${response.statusCode})',
      };
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
          'location_id': newId,
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'เพิ่มห้องไม่สำเร็จ',
      };
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
        return {
          'success': false,
          'message': data['message'] ?? 'ไม่สามารถลบห้องได้',
        };
      }

      debugPrint('❌ ลบห้องไม่สำเร็จ: ${response.body}');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการลบห้อง'};
    } catch (e) {
      debugPrint('🚨 Delete location error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  // แก้ไขห้อง (Location) - รองรับแก้ชื่อห้อง หรือแก้ชั้น (API Update)
  Future<Map<String, dynamic>> updateRoomLocation(
    int locationId, {
    String? roomName,
    String? floor,
  }) async {
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
  Future<Map<String, dynamic>> reportProblem(
    String assetId,
    String reporterName,
    String issueDetail, {
    String? imageUrl, // เพิ่ม optional parameter
  }) async {
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
          if (imageUrl != null) 'image_url': imageUrl, // ส่ง image_url ถ้ามี
        }),
      );

      debugPrint('📡 Report Status: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'แจ้งปัญหาเรียบร้อยแล้ว'};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'แจ้งปัญหาไม่สำเร็จ',
      };
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

  // ดึงประวัติการแจ้งซ่อมของครุภัณฑ์รายเครื่อง (Bo's New Endpoint)
  Future<List<Map<String, dynamic>>> getAssetReports(String assetId) async {
    try {
      debugPrint('🔄 กำลังเรียก API: $baseUrl/assets/$assetId/reports');
      final response = await http.get(
        Uri.parse('$baseUrl/assets/$assetId/reports'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Asset Reports Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Get asset reports error: $e');
      return [];
    }
  }

  /// ดึงรายการแจ้งปัญหาของผู้ใช้ (สำหรับหน้า "การแจ้งปัญหาของฉัน")
  /// GET /api/reports/user/:reporterName
  Future<List<Map<String, dynamic>>> getMyReports(String reporterName) async {
    try {
      final encodedName = Uri.encodeComponent(reporterName);
      debugPrint('📋 กำลังดึงรายการแจ้งปัญหาของ: $reporterName');

      final response = await http.get(
        Uri.parse('$baseUrl/reports/user/$encodedName'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      debugPrint('📡 My Reports Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ พบ ${data.length} รายการ');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        debugPrint('❌ ไม่พบข้อมูล หรือ Server Error');
        return [];
      }
    } catch (e) {
      debugPrint('🚨 Get my reports error: $e');
      return [];
    }
  }

  // ⭐ ดึงประวัติการตรวจสอบของ Admin (จาก check_logs)
  Future<List<Map<String, dynamic>>> getCheckLogsByChecker(
    String checkerName,
  ) async {
    try {
      final encodedName = Uri.encodeComponent(checkerName);
      debugPrint('📋 กำลังดึงประวัติการดำเนินการของ: $checkerName');

      final response = await http.get(
        Uri.parse('$baseUrl/check-logs/checker/$encodedName'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      debugPrint('📡 Check Logs Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ พบ ${data.length} รายการตรวจสอบ');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        debugPrint('❌ ไม่พบข้อมูล หรือ Server Error');
        return [];
      }
    } catch (e) {
      debugPrint('🚨 Get check logs by checker error: $e');
      return [];
    }
  }

  // ลบรายงานการแจ้งซ่อม
  Future<Map<String, dynamic>> deleteReport(int reportId) async {
    try {
      debugPrint('🔄 กำลังลบรายงาน ID: $reportId');
      final response = await http.delete(
        Uri.parse('$baseUrl/reports/$reportId'),
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

  // บันทึกการตรวจสอบครุภัณฑ์ (Check Logs)
  Future<Map<String, dynamic>> createCheckLog({
    required String assetId,
    required int checkerId, // Bo ขอ checker_id
    required String resultStatus, // Bo ขอ result_status
    String? remark, // Bo ขอ remark
    String? imageUrl, // Bo เพิ่มมาใหม่: image_url
  }) async {
    try {
      debugPrint('🔄 กำลังบันทึกการตรวจสอบ: $assetId');

      final response = await http.post(
        Uri.parse('$baseUrl/check-logs'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'asset_id': assetId,
          'checker_id': checkerId,
          'result_status': resultStatus,
          'remark': remark ?? '',
          'image_url': imageUrl ?? '', // ส่ง image_url ไปด้วย
        }),
      );

      debugPrint('📡 Check Log Status: ${response.statusCode}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'บันทึกการตรวจสอบเรียบร้อยแล้ว'};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'บันทึกไม่สำเร็จ',
      };
    } catch (e) {
      debugPrint('🚨 Create check log error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  // ดึงประวัติการตรวจสอบ (Check Logs)
  Future<List<Map<String, dynamic>>> getCheckLogs(String assetId) async {
    try {
      debugPrint('🔄 กำลังเรียก API: $baseUrl/assets/$assetId/check-logs');
      final response = await http.get(
        Uri.parse('$baseUrl/assets/$assetId/check-logs'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Check Logs Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Get check logs error: $e');
      return [];
    }
  }

  Future<dynamic> verifyPassword(String text) async {}

  // ดึงข้อมูล Dashboard Stats (4 Blocks)
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      debugPrint('🔄 กำลังเรียก API: $baseUrl/dashboard-stats');
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard-stats'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Dashboard Stats Status: ${response.statusCode}');
      debugPrint('📄 Stats Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'total': int.tryParse(data['total'].toString()) ?? 0,
          'normal': int.tryParse(data['normal'].toString()) ?? 0,
          'pending': int.tryParse(data['pending'].toString()) ?? 0,
          'damaged': int.tryParse(data['damaged'].toString()) ?? 0,
        };
      }
      return {'total': 0, 'normal': 0, 'pending': 0, 'damaged': 0};
    } catch (e) {
      debugPrint('🚨 Get dashboard stats error: $e');
      return {'total': 0, 'normal': 0, 'pending': 0, 'damaged': 0};
    }
  }

  // ========== User Management APIs (Bo's Backend) ==========

  /// ดึงรายชื่อผู้ใช้ที่รออนุมัติ
  /// GET /api/users/pending
  Future<List<Map<String, dynamic>>> getPendingUsersFromAPI() async {
    try {
      debugPrint('🔄 กำลังดึงข้อมูลผู้ใช้ที่รออนุมัติจาก API...');

      final response = await http.get(
        Uri.parse('$baseUrl/users/pending'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Get Pending Users Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ ดึงข้อมูล ${data.length} คนที่รออนุมัติ');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Get pending users error: $e');
      return [];
    }
  }

  /// อนุมัติผู้ใช้ทั้งหมดที่รออยู่
  /// PUT /api/users/approve-all
  Future<Map<String, dynamic>> approveAllUsersAPI() async {
    try {
      debugPrint('🔄 กำลังอนุมัติผู้ใช้ทั้งหมด...');

      final response = await http.put(
        Uri.parse('$baseUrl/users/approve-all'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Approve All Status: ${response.statusCode}');
      debugPrint('📄 Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ ${data['message']}');
        return {
          'success': true,
          'message': data['message'] ?? 'อนุมัติผู้ใช้งานทั้งหมดเรียบร้อยแล้ว',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'อนุมัติไม่สำเร็จ',
      };
    } catch (e) {
      debugPrint('🚨 Approve all users error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  /// อนุมัติผู้ใช้รายบุคคล
  /// PUT /api/users/approve/:id
  Future<Map<String, dynamic>> approveUserAPI(int userId) async {
    try {
      debugPrint('🔄 กำลังอนุมัติผู้ใช้ ID: $userId');

      final response = await http.put(
        Uri.parse('$baseUrl/users/approve/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Approve User Status: ${response.statusCode}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ อนุมัติผู้ใช้สำเร็จ');
        return {
          'success': true,
          'message': data['message'] ?? 'อนุมัติผู้ใช้งานเรียบร้อยแล้ว',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'อนุมัติไม่สำเร็จ',
      };
    } catch (e) {
      debugPrint('🚨 Approve user error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  /// ดึงข้อมูลผู้ใช้ทั้งหมด
  /// GET /api/users/all
  Future<List<Map<String, dynamic>>> getAllUsersFromAPI() async {
    try {
      debugPrint('🔄 กำลังดึงข้อมูลผู้ใช้ทั้งหมดจาก API...');

      final response = await http.get(
        Uri.parse('$baseUrl/users/all'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Get All Users Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ ดึงข้อมูล ${data.length} ผู้ใช้ทั้งหมด');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Get all users error: $e');
      return [];
    }
  }

  /// เปลี่ยนตำแหน่งผู้ใช้งาน (Admin <-> Checker <-> User)
  /// PUT /api/users/role/:id
  Future<Map<String, dynamic>> changeUserRoleAPI(
    int userId,
    String newRole,
  ) async {
    try {
      debugPrint('🔄 กำลังเปลี่ยนตำแหน่งผู้ใช้ ID: $userId เป็น $newRole');

      final response = await http.put(
        Uri.parse('$baseUrl/users/role/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'role': newRole}),
      );

      debugPrint('📡 Change Role Status: ${response.statusCode}');
      debugPrint('📄 Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'เปลี่ยนตำแหน่งเรียบร้อยแล้ว',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'เปลี่ยนตำแหน่งไม่สำเร็จ',
      };
    } catch (e) {
      debugPrint('🚨 Change role error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  /// ลบผู้ใช้งานออกจากระบบ
  /// DELETE /api/users/:id
  Future<Map<String, dynamic>> deleteUserAPI(int userId) async {
    try {
      debugPrint('🗑️ กำลังลบผู้ใช้ ID: $userId');

      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('📡 Delete User Status: ${response.statusCode}');
      debugPrint('📄 Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'ลบผู้ใช้งานเรียบร้อยแล้ว',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'ลบผู้ใช้ไม่สำเร็จ',
      };
    } catch (e) {
      debugPrint('🚨 Delete user error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  /// อนุมัติผู้ใช้เฉพาะที่เลือก (Approve Selected Users)
  /// PUT /api/users/approve-selected
  Future<Map<String, dynamic>> approveSelectedUsersAPI(
    List<int> userIds,
  ) async {
    try {
      debugPrint('🔄 กำลังอนุมัติผู้ใช้ที่เลือก ${userIds.length} คน...');

      final response = await http.put(
        Uri.parse('$baseUrl/users/approve-selected'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'user_ids': userIds}),
      );

      debugPrint('📡 Approve Selected Status: ${response.statusCode}');
      debugPrint('📄 Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ ${data['message']}');
        return {
          'success': true,
          'message': data['message'] ?? 'อนุมัติผู้ใช้ที่เลือกเรียบร้อยแล้ว',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'อนุมัติไม่สำเร็จ',
      };
    } catch (e) {
      debugPrint('🚨 Approve selected users error: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้'};
    }
  }

  /// อัปโหลดรูปภาพไปยัง Backend ของโบ
  /// POST /api/upload
  Future<String?> uploadImage(File imageFile) async {
    try {
      debugPrint('🔄 กำลังอุปโหลดรูปภาพ: ${imageFile.path}');

      // สร้าง multipart request
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

      // เพิ่ม headers
      request.headers.addAll({'ngrok-skip-browser-warning': 'true'});

      // เพิ่มไฟล์รูปภาพ (key: 'image' ตามที่โบกำหนด)
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      // ส่ง request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('📡 Upload Status: ${response.statusCode}');
      debugPrint('📄 Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['image_url'] as String?;

        if (imageUrl != null) {
          debugPrint('✅ อัปโหลดสำเร็จ: $imageUrl');
          return imageUrl;
        }
      }

      debugPrint('❌ อัปโหลดไม่สำเร็จ');
      return null;
    } catch (e) {
      debugPrint('🚨 Upload image error: $e');
      return null;
    }
  }
}
