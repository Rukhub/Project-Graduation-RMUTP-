import 'package:flutter/material.dart';
import 'krupan_room.dart'; // import ไฟล์หน้าห้อง
import 'api_service.dart'; // import api_service
import 'app_drawer.dart';

class KrupanScreen extends StatefulWidget {
  const KrupanScreen({super.key});

  @override
  State<KrupanScreen> createState() => _KrupanScreenState();
}

class _KrupanScreenState extends State<KrupanScreen> {
  // เก็บชั้นที่เลือกอยู่
  int selectedFloor = 1;
  // ไม่ใช้ DataService แล้วสำหรับการดึงห้อง
  // final DataService _dataService = DataService();
  
  // เก็บข้อมูลห้องที่ดึงจาก API: { 1: [{'location_id': 1, 'room_name': 'Room 1'}, ...], ... }
  Map<int, List<Map<String, dynamic>>> apiFloorRooms = {};
  bool _isLoading = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // === Helper Function: แสดง Notification ด้านล่าง ===
  void _showBottomNotification({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    // ลบ overlay เก่าถ้ามี
    _removeCurrentOverlay();
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _BottomNotificationWidget(
        message: message,
        icon: icon,
        color: color,
        onDismiss: () {
          overlayEntry.remove();
          _currentOverlay = null;
        },
      ),
    );
    
    _currentOverlay = overlayEntry;
    overlay.insert(overlayEntry);
  }
  
  OverlayEntry? _currentOverlay;
  
  void _removeCurrentOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      final locations = await ApiService().getLocations();
      
      // จัดกลุ่มห้องตามชั้น
      Map<int, List<Map<String, dynamic>>> tempFloorRooms = {};
      
      for (var loc in locations) {
        // Parse floor: "ชั้น 1" -> 1
        String floorStr = loc['floor']?.toString() ?? '';
        int? floor;
        
        // พยายามดึงตัวเลขจาก string
        final RegExp digitRegex = RegExp(r'\d+');
        final match = digitRegex.firstMatch(floorStr);
        if (match != null) {
          floor = int.parse(match.group(0)!);
        } else {
          // Fallback ถ้าไม่ใช่ format "ชั้น X" ให้ลอง cast ตรงๆ หรือข้าม
          floor = int.tryParse(floorStr);
        }

        if (floor != null) {
          if (!tempFloorRooms.containsKey(floor)) {
            tempFloorRooms[floor] = [];
          }
          // เก็บทั้ง Object เพื่อให้มี location_id ไว้ลบ
          tempFloorRooms[floor]!.add(loc);
        }
      }

      // เรียงลำดับห้องในแต่ละชั้น (ตามชื่อ)
      for (var key in tempFloorRooms.keys) {
        tempFloorRooms[key]!.sort((a, b) => (a['room_name'] as String).compareTo(b['room_name'] as String));
      }

      setState(() {
        apiFloorRooms = tempFloorRooms;
        _isLoading = false;
        
        // ถ้าชั้นที่เลือกไม่มีในข้อมูลใหม่ ให้เปลี่ยนไปชั้นแรกที่มี
        if (!apiFloorRooms.containsKey(selectedFloor) && apiFloorRooms.isNotEmpty) {
          selectedFloor = apiFloorRooms.keys.reduce((a, b) => a < b ? a : b); // เลือกชั้นต่ำสุด
        }
      });
      
    } catch (e) {
      debugPrint('Error loading locations: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ข้อมูลจาก API (ตอนนี้เป็น List<Map>)
    List<Map<String, dynamic>> rooms = apiFloorRooms[selectedFloor] ?? [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF9A2C2C)),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: GestureDetector(
          onTap: () => _showFloorPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ชั้น $selectedFloor',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 30),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          const SizedBox(width: 10),
        ],
        toolbarHeight: 80,
      ),
      body: rooms.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              children: [
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF9A2C2C)))
                else ...[
                  // แสดงรายการห้องของชั้นที่เลือก
                  ...rooms.map((room) => buildRoomCard(room)),
                  const SizedBox(height: 80),
                ],
              ],
            ),
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          onPressed: () => _showAddRoomDialog(context),
          backgroundColor: const Color(0xFF9A2C2C),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 40, color: Colors.white),
        ),
      ),
    );
  }

  // ฟังก์ชันแสดง Dropdown เลือกชั้น
  void _showFloorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<int> sortedFloors = apiFloorRooms.keys.toList()..sort();
            
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.layers, color: Color(0xFF9A2C2C), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'จัดการชั้น',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'เลือก เพิ่ม หรือลบชั้น',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Divider
                  Divider(color: Colors.grey.shade200, height: 1),
                  
                  // Floor List
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: sortedFloors.length,
                      itemBuilder: (context, index) {
                        int floor = sortedFloors[index];
                        int roomCount = apiFloorRooms[floor]?.length ?? 0;
                        bool isSelected = selectedFloor == floor;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFF9A2C2C).withValues(alpha: 0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFF9A2C2C).withValues(alpha: 0.3)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  selectedFloor = floor;
                                });
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Floor Icon
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFF9A2C2C)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$floor',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Floor Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ชั้น $floor',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? const Color(0xFF9A2C2C) : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.meeting_room_outlined,
                                                size: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                roomCount > 0 ? '$roomCount ห้อง' : 'ยังไม่มีห้อง',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: roomCount > 0 ? Colors.grey.shade600 : Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Selected Check
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF9A2C2C),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                                      ),
                                    
                                    // Edit & Delete Button
                                    if (!isSelected)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Edit
                                          IconButton(
                                            onPressed: () => _showEditFloorDialog(context, floor, setModalState),
                                            icon: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.edit,
                                                color: Colors.blue.shade400,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          // Delete
                                          IconButton(
                                            onPressed: () => _handleDeleteFloor(context, floor, setModalState),
                                            icon: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red.shade400,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Add Floor Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddFloorDialog(context);
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 24),
                        label: const Text(
                          'เพิ่มชั้นใหม่',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9A2C2C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  
                  // Safe area padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // === Handle Edit Floor ===
  void _showEditFloorDialog(BuildContext modalContext, int oldFloor, StateSetter setModalState) {
    final TextEditingController floorController = TextEditingController(text: oldFloor.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('แก้ไขเลขชั้น'),
          content: TextField(
            controller: floorController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'เลขชั้น (เช่น 5)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.layers),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                String input = floorController.text.trim();
                if (input.isNotEmpty) {
                  int? newFloor = int.tryParse(input);
                  if (newFloor != null && newFloor != oldFloor) {
                    // Check if new floor already exists (Optional: Merge?)
                    if (apiFloorRooms.containsKey(newFloor)) {
                       ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('มีชั้น $newFloor อยู่แล้ว ไม่สามารถเปลี่ยนเป็นชั้นซ้ำกันได้')),
                       );
                    } else {
                       // เริ่มกระบวนการย้ายชั้น
                       // ต้อง update ทุกห้องในชั้น oldFloor ให้เป็น newFloor
                       // เนื่องจากไม่มี API updateMany จึงต้องวนลูป
                       Navigator.pop(context); // ปิด Dialog
                       Navigator.pop(modalContext); // ปิด Picker เพื่อ Refresh

                       setState(() => _isLoading = true);

                       List<Map<String, dynamic>> roomsToMove = apiFloorRooms[oldFloor] ?? [];
                       bool allSuccess = true;
                       
                       for (var room in roomsToMove) {
                         int locationId = int.parse(room['location_id'].toString());
                         String currentRoomName = room['room_name']; // ดึงชื่อห้องเดิม
                         
                         // Update floor (ส่งทั้ง floor และ room_name ตามที่ API บังคับ)
                         final res = await ApiService().updateRoomLocation(
                           locationId, 
                           floor: 'ชั้น $newFloor',
                           roomName: currentRoomName, 
                         );
                         
                         if (res['success'] != true) {
                           allSuccess = false;
                         }
                       }

                       if (allSuccess) {
                         _showBottomNotification(
                            message: 'เปลี่ยนจากชั้น $oldFloor เป็น $newFloor สำเร็จ', 
                            icon: Icons.check_circle, 
                            color: Colors.green
                         );
                       } else {
                          _showBottomNotification(
                            message: 'บางห้องอัปเดตไม่สำเร็จ กรุณาลองใหม่', 
                            icon: Icons.warning, 
                            color: Colors.orange
                         );
                       }

                       // Reload Data
                       _loadLocations(); 
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // === Handle Delete Floor (จาก UI) ===
  void _handleDeleteFloor(BuildContext modalContext, int floor, StateSetter setModalState) async {
    // ถ้าเป็นชั้นสุดท้าย ห้ามลบ
    if (apiFloorRooms.keys.length == 1) {
      _showBottomNotification(
        message: 'ไม่สามารถลบชั้นสุดท้ายได้',
        icon: Icons.error_outline,
        color: Colors.red,
      );
      return;
    }
    
    // ตรวจสอบว่าชั้นนี้มีห้องหรือไม่
    if (apiFloorRooms[floor]?.isNotEmpty == true) {
      // ถ้ามีห้อง ต้องใส่รหัสผ่านก่อนลบ
      Navigator.pop(modalContext); // ปิด Floor Picker ก่อน
      final result = await _showPasswordConfirmDialog(floor);
      if (result) {
        _deleteFloor(floor);
      }
    } else {
      // ถ้าไม่มีห้อง แสดง Confirmation Dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('ยืนยันการลบชั้น'),
            ],
          ),
          content: Text('คุณต้องการลบ "ชั้น $floor" ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        // ลบและ update modal
        setModalState(() {
          apiFloorRooms.remove(floor);
        });
        setState(() {}); // Update main screen
        _showBottomNotification(
          message: 'ลบชั้น $floor สำเร็จ',
          icon: Icons.delete_sweep,
          color: Colors.red,
        );
      }
    }
  }

  // Dialog เพิ่มชั้นใหม่
  void _showAddFloorDialog(BuildContext context) {
    final TextEditingController floorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('เพิ่มชั้นใหม่'),
          content: TextField(
            controller: floorController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'เลขชั้น (เช่น 5)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.layers),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                String input = floorController.text.trim();
                if (input.isNotEmpty) {
                  int? newFloor = int.tryParse(input);
                  if (newFloor != null) {
                    if (apiFloorRooms.containsKey(newFloor)) {
                       // ถ้ามีชั้นนี้อยู่แล้ว ให้แจ้งเตือน หรือแค่ย้ายไปชั้นนั้น
                       setState(() {
                         selectedFloor = newFloor;
                       });
                       Navigator.pop(context);
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('มีชั้น $newFloor อยู่แล้ว ย้ายไปยังชั้น $newFloor')),
                       );
                    } else {
                      // สร้างชั้นใหม่ (Empty)
                      setState(() {
                        apiFloorRooms[newFloor] = []; // สร้าง List ว่าง
                        selectedFloor = newFloor; // ย้ายไปชั้นใหม่ทันที
                        
                        // Re-sort keys logic if needed, but Map keys aren't ordered automatically in Dart Map literal unless LinkedHashMap (default).
                        // But when we build ListView, we sort keys every time: `sortedFloors = apiFloorRooms.keys.toList()..sort();`
                        // So just adding it is fine.
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text('สร้างชั้น $newFloor สำเร็จ! กรุณาเพิ่มห้องเพื่อบันทึก'),
                           backgroundColor: Colors.green,
                           duration: const Duration(seconds: 4),
                         ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('กรุณากรอกตัวเลขเท่านั้น')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2C2C),
              ),
              child: const Text('สร้าง', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันแสดง Dialog เพิ่มห้อง
  void _showAddRoomDialog(BuildContext context) {
    final TextEditingController roomController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('เพิ่มห้องใหม่'),
          content: TextField(
            controller: roomController,
            decoration: const InputDecoration(
              hintText: 'ชื่อห้อง (Ex. Room 1001)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (roomController.text.isNotEmpty) {
                  // เรียก API เพิ่มห้อง
                  final result = await ApiService().addLocation(
                    selectedFloor,
                    roomController.text,
                  );

                  if (context.mounted) {
                    Navigator.pop(context); // ปิด Dialog
                    
                    if (result['success']) {
                      // แสดง Notification ด้านล่าง (สีเขียว)
                      _showBottomNotification(
                        message: 'เพิ่มห้อง "${roomController.text}" สำเร็จ',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      );

                      // Optimistic Update: เพิ่มห้องเข้า List ทันที
                      setState(() {
                        if (!apiFloorRooms.containsKey(selectedFloor)) {
                          apiFloorRooms[selectedFloor] = [];
                        }
                        
                        // สร้าง Object ห้องใหม่
                        // ถ้า Server ส่ง ID กลับมาให้ใช้ ID นั้น ถ้าไม่มีให้ใช้ 0 ไปก่อน (แต่มันจะลบไม่ได้ใน session นี้)
                        int newId = result['location_id'] ?? 0;
                        
                        apiFloorRooms[selectedFloor]!.add({
                          'location_id': newId,
                          'room_name': roomController.text,
                          'floor': 'ชั้น $selectedFloor'
                        });

                        // จัดเรียง
                        apiFloorRooms[selectedFloor]!.sort((a, b) => (a['room_name'] as String).compareTo(b['room_name'] as String));
                      });

                      // โหลดข้อมูลจริงตามมา (เผื่อ ID ผิดหรือต้องการข้อมูลอื่นเพิ่ม)
                      // กรณีนี้ไม่ต้อง Loading Screen ก็ได้เพื่อให้ดู Realtime
                      // _loadLocations(); // ถ้าอยากชัวร์ก็เปิดหรืือทำแบบ silent update
                    } else {
                      // แสดง Notification ด้านล่าง (สีแดง - Error)
                      _showBottomNotification(
                        message: result['message'] ?? 'เกิดข้อผิดพลาด',
                        icon: Icons.error_outline,
                        color: Colors.red,
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2C2C),
              ),
              child: const Text('เพิ่ม', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Dialog แก้ไขห้อง
  void _showEditRoomDialog(Map<String, dynamic> room) {
    final TextEditingController roomController = TextEditingController(text: room['room_name']);
    int locationId = int.parse(room['location_id'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('แก้ไขชื่อห้อง'),
          content: TextField(
            controller: roomController,
            decoration: const InputDecoration(
              hintText: 'ชื่อห้อง (Ex. Room 1001)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                String newName = roomController.text.trim();
                if (newName.isNotEmpty && newName != room['room_name']) {
                  // เรียก API แก้ไข (ต้องส่งทั้งชั้นและชื่อห้อง ตามที่ Server บังคับ)
                  final result = await ApiService().updateRoomLocation(
                    locationId, 
                    roomName: newName,
                    floor: 'ชั้น $selectedFloor', // ส่งชั้นปัจจุบันไปด้วย
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    if (result['success']) {
                       _showBottomNotification(
                        message: 'แก้ไขชื่อห้องเป็น "$newName" สำเร็จ',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      );
                      setState(() {
                        // Update UI
                        final index = apiFloorRooms[selectedFloor]?.indexWhere((element) => element['location_id'].toString() == locationId.toString());
                        if (index != null && index != -1) {
                            apiFloorRooms[selectedFloor]![index]['room_name'] = newName;
                            // Re-sort
                             apiFloorRooms[selectedFloor]!.sort((a, b) => (a['room_name'] as String).compareTo(b['room_name'] as String));
                        }
                      });
                    } else {
                       _showBottomNotification(
                        message: result['message'] ?? 'แก้ไขไม่สำเร็จ',
                        icon: Icons.error_outline,
                        color: Colors.red,
                      );
                    }
                  }
                } else {
                   Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2C2C),
              ),
              child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Widget แสดงเมื่อไม่มีห้อง
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined,
              size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            'ยังไม่มีห้องในชั้นนี้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'กดปุ่ม + เพื่อเพิ่มห้องใหม่',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // Widget การ์ดห้อง
  Widget buildRoomCard(Map<String, dynamic> room) {
    String roomName = room['room_name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // ส่ง object ห้องไปที่หน้า krupan_room ก็ได้ถ้าต้องการ แต่ตอนนี้เขารับ roomName
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KrupanRoomScreen(
                  roomName: roomName,
                  floor: selectedFloor,
                  locationId: int.parse(room['location_id'].toString()),
                ),
              ),
            );
          },
          onLongPress: () => _showDeleteRoomDialog(room),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.meeting_room,
                    color: Color(0xFF9A2C2C),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ชั้น $selectedFloor',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // ปุ่มแก้ไข
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue.shade300, size: 24),
                  tooltip: 'แก้ไขห้อง',
                  onPressed: () => _showEditRoomDialog(room),
                ),
                // ปุ่มลบ
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 24),
                  tooltip: 'ลบห้อง',
                  onPressed: () => _showDeleteRoomDialog(room),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Dialog ยืนยันลบห้อง
  void _showDeleteRoomDialog(Map<String, dynamic> room) {
    String roomName = room['room_name'];
    int locationId = int.parse(room['location_id'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('ยืนยันการลบห้อง', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'คุณต้องการลบห้อง "$roomName" ใช่หรือไม่?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () async {
                // เรียก API ลบห้อง
                final result = await ApiService().deleteLocation(locationId);

                if (context.mounted) {
                  Navigator.pop(context); // ปิด Dialog
                  
                  if (result['success'] == true) {
                    // แสดง Notification ด้านล่าง (สีแดง)
                    _showBottomNotification(
                      message: 'ลบห้อง "$roomName" สำเร็จ',
                      icon: Icons.delete_sweep,
                      color: Colors.red,
                    );

                    // ลบออกจาก List
                    setState(() {
                      apiFloorRooms[selectedFloor]?.removeWhere((r) => 
                        r['location_id'].toString() == locationId.toString()
                      );
                    });
                  } else {
                    // แสดง Notification ด้านล่าง (สีแดง - Error)
                    _showBottomNotification(
                      message: result['message'] ?? 'ไม่สามารถลบห้องได้',
                      icon: Icons.error_outline,
                      color: Colors.red,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ลบ', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  // === Dialog ใส่รหัสผ่านก่อนลบชั้นที่มีห้อง ===
  Future<bool> _showPasswordConfirmDialog(int floor) async {
    final TextEditingController passwordController = TextEditingController();
    String? errorMessage;
    bool isDeleting = false;
    
    final rooms = apiFloorRooms[floor] ?? [];
    final roomNames = rooms.map((r) => r['room_name'] as String).toList();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ลบชั้นและห้องทั้งหมด',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // คำเตือน
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ชั้น $floor มี ${rooms.length} ห้อง จะถูกลบทั้งหมด!',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // รายการห้องที่จะถูกลบ
                    const Text('ห้องที่จะถูกลบ:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: roomNames.map((name) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.meeting_room, size: 16, color: Colors.red.shade300),
                                const SizedBox(width: 8),
                                Text(name, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // ช่องใส่คำว่า Delete เพื่อยืนยัน
                    const Text('พิมพ์ "Delete" เพื่อยืนยันการลบ:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        hintText: 'Delete',
                        prefixIcon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        errorText: errorMessage,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context, false),
                  child: Text('ยกเลิก', style: TextStyle(color: isDeleting ? Colors.grey.shade300 : Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isDeleting ? null : () async {
                    // แสดง loading ระหว่าง verify
                    setDialogState(() {
                      isDeleting = true;
                      errorMessage = null;
                    });
                    
                    // ตรวจสอบว่าพิมพ์คำว่า Delete ถูกต้องหรือไม่
                    if (passwordController.text != 'Delete') {
                      setDialogState(() {
                        isDeleting = false;
                        errorMessage = 'กรุณาพิมพ์คำว่า "Delete" เพื่อยืนยัน';
                      });
                      return;
                    }
                    
                    // คำยืนยันถูกต้อง - เริ่มลบห้อง
                    
                    // ลบห้องทั้งหมดใน Database
                    bool allSuccess = true;
                    for (var room in rooms) {
                      final locationId = int.parse(room['location_id'].toString());
                      final result = await ApiService().deleteLocation(locationId);
                      if (result['success'] != true) {
                        allSuccess = false;
                        break;
                      }
                    }
                    
                    if (context.mounted) {
                      Navigator.pop(context, allSuccess);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeleting ? Colors.grey : Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('ยืนยันลบ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
    
    return result ?? false;
  }

  // ฟังก์ชันลบชั้น (รองรับทั้งชั้นว่างและชั้นที่มีห้อง)
  void _deleteFloor(int floor) {
    setState(() {
      // ลบชั้นออกจาก Map
      apiFloorRooms.remove(floor);
      
      // ถ้าชั้นที่ลบคือชั้นที่เลือกอยู่ ให้ย้ายไปชั้นอื่น
      if (selectedFloor == floor) {
        if (apiFloorRooms.isNotEmpty) {
          // เลือกชั้นแรกที่เหลือ
          selectedFloor = apiFloorRooms.keys.reduce((a, b) => a < b ? a : b);
        }
      }
    });
    
    // แสดง Notification ด้านล่าง
    _showBottomNotification(
      message: 'ลบชั้น $floor สำเร็จ',
      icon: Icons.delete_sweep,
      color: Colors.red,
    );
  }
}

// === Widget: iPhone-style Notification ===
// === Widget: Bottom Notification ===
class _BottomNotificationWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _BottomNotificationWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_BottomNotificationWidget> createState() => _BottomNotificationWidgetState();
}

class _BottomNotificationWidgetState extends State<_BottomNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // เริ่มจากด้านล่าง (ซ่อน)
      end: Offset.zero, // เลื่อนขึ้นมา
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Auto dismiss หลัง 2.5 วินาที
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_isDismissed) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20, // เหนือขอบล่าง / home indicator
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            // ปัดลงเพื่อปิด
            if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
              _dismiss();
            }
          },
          onTap: _dismiss, // แตะเพื่อปิด
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: widget.color,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(widget.icon, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // ไอคอนลูกศรลง (บอกว่าปัดลงได้)
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}