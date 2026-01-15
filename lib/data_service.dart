// data_service.dart

class DataService {
  // Singleton Pattern
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // ข้อมูลห้องในแต่ละชั้น
  final Map<int, List<String>> floorRooms = {
    1: ['Room 1951', 'Room 1952', 'Room 1953', 'Room 1954', 'Room 1955', 'Room 1956', 'Room 1957', 'Room 1958'],
    2: [],
    3: ['Room 3001', 'Room 3002'],
    4: ['Room 4001'],
    5: ['Room 5001', 'Room 5002', 'Room 5003'],
    6: ['Room 6001'],
  };

  // ข้อมูลครุภัณฑ์ทั้งหมด (Key = Room Name)
  final Map<String, List<Map<String, dynamic>>> roomEquipments = {
    'Room 1951': [
      {
        'id': '1-104-7440-006-0006/013-67',
        'type': 'หน้าจอ',
        'status': 'ปกติ',
        'images': [],
        'inspectorName': null,
        'reporterName': null,
      },
      {
        'id': '1-104-7440-006-0006/014-67',
        'type': 'PC',
        'status': 'ปกติ',
        'images': [],
      },
      {
        'id': '1-104-7440-006-0006/015-67',
        'type': 'คีย์บอร์ด',
        'status': 'ชำรุด',
        'reporterName': 'สมชาย ใจดี',
        'reportReason': 'ปุ่มกดไม่ติด',
        'reportImages': [],
      },
    ],
    'Room 1952': [
      {'id': '1-104-7440-006-0007/001-67', 'type': 'PC', 'status': 'ปกติ'},
    ],
  };

  // ดึงข้อมูลครุภัณฑ์ในห้อง
  List<Map<String, dynamic>> getEquipmentsInRoom(String roomName) {
    if (!roomEquipments.containsKey(roomName)) {
      roomEquipments[roomName] = [];
    }
    return roomEquipments[roomName]!;
  }

  // เพิ่มครุภัณฑ์
  void addEquipment(String roomName, Map<String, dynamic> equipment) {
    if (!roomEquipments.containsKey(roomName)) {
      roomEquipments[roomName] = [];
    }
    roomEquipments[roomName]!.add(equipment);
  }

  // อัปเดตครุภัณฑ์
  void updateEquipment(String roomName, Map<String, dynamic> updatedEquipment) {
    if (roomEquipments.containsKey(roomName)) {
      final list = roomEquipments[roomName]!;
      final index = list.indexWhere((e) => e['id'] == updatedEquipment['id']);
      if (index != -1) {
        list[index] = updatedEquipment;
      }
    }
  }

  // ลบครุภัณฑ์
  void deleteEquipment(String roomName, String id) {
     if (roomEquipments.containsKey(roomName)) {
       roomEquipments[roomName]!.removeWhere((e) => e['id'] == id);
     }
  }

  // เพิ่มห้องใหม่ในชั้นที่กำหนด
  void addRoom(int floor, String roomName) {
    if (!floorRooms.containsKey(floor)) {
      floorRooms[floor] = [];
    }
    if (!floorRooms[floor]!.contains(roomName)) {
      floorRooms[floor]!.add(roomName);
    }
  }
}
