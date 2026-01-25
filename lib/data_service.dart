import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DataService {
  // Singleton Pattern
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  static Database? _database;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'equipment_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // สร้างตาราง users
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            name TEXT NOT NULL
          )
        ''');

        // สร้างตาราง rooms
        await db.execute('''
          CREATE TABLE rooms(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            floor INTEGER NOT NULL,
            name TEXT NOT NULL,
            UNIQUE(floor, name)
          )
        ''');

        // สร้างตาราง equipment
        await db.execute('''
          CREATE TABLE equipment(
            id TEXT PRIMARY KEY,
            room_name TEXT NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            inspector_name TEXT,
            reporter_name TEXT,
            report_reason TEXT,
            FOREIGN KEY (room_name) REFERENCES rooms (name) ON DELETE CASCADE
          )
        ''');

        // สร้างตาราง equipment_images (รูปอุปกรณ์ปกติ)
        await db.execute('''
          CREATE TABLE equipment_images(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            equipment_id TEXT NOT NULL,
            image_path TEXT NOT NULL,
            FOREIGN KEY (equipment_id) REFERENCES equipment (id) ON DELETE CASCADE
          )
        ''');

        // สร้างตาราง inspector_images (รูปจากผู้ตรวจ)
        await db.execute('''
          CREATE TABLE inspector_images(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            equipment_id TEXT NOT NULL,
            image_path TEXT NOT NULL,
            FOREIGN KEY (equipment_id) REFERENCES equipment (id) ON DELETE CASCADE
          )
        ''');

        // สร้างตาราง report_images (รูปจากผู้แจ้ง)
        await db.execute('''
          CREATE TABLE report_images(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            equipment_id TEXT NOT NULL,
            image_path TEXT NOT NULL,
            FOREIGN KEY (equipment_id) REFERENCES equipment (id) ON DELETE CASCADE
          )
        ''');

        // เพิ่มข้อมูลเริ่มต้น
        await _insertInitialData(db);
      },
    );
  }

  // เพิ่มข้อมูลเริ่มต้น
  Future<void> _insertInitialData(Database db) async {
    // เพิ่ม user ทดสอบ
    await db.insert('users', {
      'username': 'admin',
      'password': '1234',
      'name': 'ผู้ดูแลระบบ',
    });

    // เพิ่มห้อง
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1951'});
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1952'});
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1953'});
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1954'});
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1955'});
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1956'});
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1957'});
    await db.insert('rooms', {'floor': 1, 'name': 'Room 1958'});
    await db.insert('rooms', {'floor': 3, 'name': 'Room 3001'});
    await db.insert('rooms', {'floor': 3, 'name': 'Room 3002'});
    await db.insert('rooms', {'floor': 4, 'name': 'Room 4001'});
    await db.insert('rooms', {'floor': 5, 'name': 'Room 5001'});
    await db.insert('rooms', {'floor': 5, 'name': 'Room 5002'});
    await db.insert('rooms', {'floor': 5, 'name': 'Room 5003'});
    await db.insert('rooms', {'floor': 6, 'name': 'Room 6001'});

    // เพิ่มครุภัณฑ์ตัวอย่าง
    await db.insert('equipment', {
      'id': '1-104-7440-006-0006/013-67',
      'room_name': 'Room 1951',
      'type': 'หน้าจอ',
      'status': 'ปกติ',
    });

    await db.insert('equipment', {
      'id': '1-104-7440-006-0006/014-67',
      'room_name': 'Room 1951',
      'type': 'เคสคอม',
      'status': 'ปกติ',
    });

    await db.insert('equipment', {
      'id': '1-104-7440-006-0006/015-67',
      'room_name': 'Room 1951',
      'type': 'คีย์บอร์ด',
      'status': 'ชำรุด',
      'reporter_name': 'สมชาย ใจดี',
      'report_reason': 'ปุ่มกดไม่ติด',
    });

    await db.insert('equipment', {
      'id': '1-104-7440-006-0007/001-67',
      'room_name': 'Room 1952',
      'type': 'เคสคอม',
      'status': 'ปกติ',
    });
  }

  // ===== USER/LOGIN METHODS =====

  // Login method
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // ===== ROOM METHODS =====

  // ดึงข้อมูลห้องทั้งหมดแยกตามชั้น (แบบ sync สำหรับความเข้ากันได้)
  Map<int, List<String>> floorRooms = {
    1: [],
    2: [],
    3: [],
    4: [],
    5: [],
    6: [],
  };

  // โหลดข้อมูลห้องจาก database
  Future<void> loadFloorRooms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rooms',
      orderBy: 'floor, name',
    );

    floorRooms = {1: [], 2: [], 3: [], 4: [], 5: [], 6: []};

    for (var map in maps) {
      int floor = map['floor'] as int;
      String name = map['name'] as String;
      if (floorRooms.containsKey(floor)) {
        floorRooms[floor]!.add(name);
      }
    }
  }

  // เพิ่มห้องใหม่
  Future<void> addRoom(int floor, String roomName) async {
    final db = await database;
    await db.insert('rooms', {
      'floor': floor,
      'name': roomName,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await loadFloorRooms(); // โหลดข้อมูลใหม่
  }

  // ลบห้อง
  Future<void> deleteRoom(int floor, String roomName) async {
    final db = await database;
    await db.delete(
      'rooms',
      where: 'floor = ? AND name = ?',
      whereArgs: [floor, roomName],
    );
    await loadFloorRooms(); // โหลดข้อมูลใหม่
  }

  // ===== EQUIPMENT METHODS =====

  // ดึงครุภัณฑ์ทั้งหมดในห้อง
  Future<List<Map<String, dynamic>>> getEquipmentsInRoomAsync(
    String roomName,
  ) async {
    final db = await database;

    // ดึงข้อมูลครุภัณฑ์
    final List<Map<String, dynamic>> rawEquipments = await db.query(
      'equipment',
      where: 'room_name = ?',
      whereArgs: [roomName],
    );

    // แปลง immutable map เป็น mutable map
    List<Map<String, dynamic>> equipments = rawEquipments
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // เพิ่มรูปภาพให้แต่ละครุภัณฑ์
    for (var equipment in equipments) {
      String equipmentId = equipment['id'];

      // ดึงรูปอุปกรณ์ปกติ
      final images = await db.query(
        'equipment_images',
        columns: ['image_path'],
        where: 'equipment_id = ?',
        whereArgs: [equipmentId],
      );
      equipment['images'] = images
          .map((e) => e['image_path'] as String)
          .toList();

      // ดึงรูปจากผู้ตรวจ
      final inspectorImages = await db.query(
        'inspector_images',
        columns: ['image_path'],
        where: 'equipment_id = ?',
        whereArgs: [equipmentId],
      );
      equipment['inspectorImages'] = inspectorImages
          .map((e) => e['image_path'] as String)
          .toList();

      // ดึงรูปจากผู้แจ้ง
      final reportImages = await db.query(
        'report_images',
        columns: ['image_path'],
        where: 'equipment_id = ?',
        whereArgs: [equipmentId],
      );
      equipment['reportImages'] = reportImages
          .map((e) => e['image_path'] as String)
          .toList();
    }

    return equipments;
  }

  // ดึงครุภัณฑ์แบบ sync (สำหรับความเข้ากันได้กับโค้ดเดิม)
  List<Map<String, dynamic>> getEquipmentsInRoom(String roomName) {
    // ใช้แค่คืนค่า list ว่างก่อน แล้วให้โหลดข้อมูลจริงด้วย getEquipmentsInRoomAsync
    return [];
  }

  // เพิ่มครุภัณฑ์
  Future<void> addEquipment(
    String roomName,
    Map<String, dynamic> equipment,
  ) async {
    final db = await database;

    // เพิ่มข้อมูลครุภัณฑ์
    await db.insert('equipment', {
      'id': equipment['id'],
      'room_name': roomName,
      'type': equipment['type'],
      'status': equipment['status'],
      'inspector_name': equipment['inspectorName'],
      'reporter_name': equipment['reporterName'],
      'report_reason': equipment['reportReason'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    String equipmentId = equipment['id'];

    // เพิ่มรูปอุปกรณ์ปกติ
    if (equipment['images'] != null) {
      for (String imagePath in equipment['images']) {
        await db.insert('equipment_images', {
          'equipment_id': equipmentId,
          'image_path': imagePath,
        });
      }
    }

    // เพิ่มรูปจากผู้ตรวจ
    if (equipment['inspectorImages'] != null) {
      for (String imagePath in equipment['inspectorImages']) {
        await db.insert('inspector_images', {
          'equipment_id': equipmentId,
          'image_path': imagePath,
        });
      }
    }

    // เพิ่มรูปจากผู้แจ้ง
    if (equipment['reportImages'] != null) {
      for (String imagePath in equipment['reportImages']) {
        await db.insert('report_images', {
          'equipment_id': equipmentId,
          'image_path': imagePath,
        });
      }
    }
  }

  // อัปเดตครุภัณฑ์
  Future<void> updateEquipment(
    String roomName,
    Map<String, dynamic> equipment,
  ) async {
    final db = await database;
    String equipmentId = equipment['id'];

    // อัปเดตข้อมูลครุภัณฑ์
    await db.update(
      'equipment',
      {
        'room_name': roomName,
        'type': equipment['type'],
        'status': equipment['status'],
        'inspector_name': equipment['inspectorName'],
        'reporter_name': equipment['reporterName'],
        'report_reason': equipment['reportReason'],
      },
      where: 'id = ?',
      whereArgs: [equipmentId],
    );

    // ลบและเพิ่มรูปอุปกรณ์ปกติใหม่
    await db.delete(
      'equipment_images',
      where: 'equipment_id = ?',
      whereArgs: [equipmentId],
    );
    if (equipment['images'] != null) {
      for (String imagePath in equipment['images']) {
        await db.insert('equipment_images', {
          'equipment_id': equipmentId,
          'image_path': imagePath,
        });
      }
    }

    // ลบและเพิ่มรูปจากผู้ตรวจใหม่
    await db.delete(
      'inspector_images',
      where: 'equipment_id = ?',
      whereArgs: [equipmentId],
    );
    if (equipment['inspectorImages'] != null) {
      for (String imagePath in equipment['inspectorImages']) {
        await db.insert('inspector_images', {
          'equipment_id': equipmentId,
          'image_path': imagePath,
        });
      }
    }

    // ลบและเพิ่มรูปจากผู้แจ้งใหม่
    await db.delete(
      'report_images',
      where: 'equipment_id = ?',
      whereArgs: [equipmentId],
    );
    if (equipment['reportImages'] != null) {
      for (String imagePath in equipment['reportImages']) {
        await db.insert('report_images', {
          'equipment_id': equipmentId,
          'image_path': imagePath,
        });
      }
    }
  }

  // ลบครุภัณฑ์
  Future<void> deleteEquipment(String roomName, String id) async {
    final db = await database;
    await db.delete(
      'equipment',
      where: 'id = ? AND room_name = ?',
      whereArgs: [id, roomName],
    );
  }

  // ===== UTILITY METHODS =====

  // ล้างข้อมูลทั้งหมด (สำหรับ testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('report_images');
    await db.delete('inspector_images');
    await db.delete('equipment_images');
    await db.delete('equipment');
    await db.delete('rooms');
    await db.delete('users');
  }

  // ปิด database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
