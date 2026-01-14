import 'package:flutter/material.dart';
import 'krupan_room.dart'; // import ไฟล์หน้าห้อง

class KrupanScreen extends StatefulWidget {
  const KrupanScreen({super.key});

  @override
  State<KrupanScreen> createState() => _KrupanScreenState();
}

class _KrupanScreenState extends State<KrupanScreen> {
  // เก็บชั้นที่เลือกอยู่
  int selectedFloor = 1;
  
  // เก็บข้อมูลห้องแต่ละชั้น (Key = ชั้น, Value = รายการห้อง)
  Map<int, List<String>> floorRooms = {
    1: ['Room 1951', 'Room 1952', 'Room 1953', 'Room 1954', 'Room 1955', 'Room 1956', 'Room 1957', 'Room 1958'],
    2: [], // ชั้น 2 ว่างเปล่า เพื่อทดสอบ Empty State
    3: ['Room 3001', 'Room 3002'],
    4: ['Room 4001'],
    5: ['Room 5001', 'Room 5002', 'Room 5003'],
    6: ['Room 6001'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
        toolbarHeight: 80,
      ),
      body: floorRooms[selectedFloor]!.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              children: [
                // แสดงรายการห้องของชั้นที่เลือก
                ...floorRooms[selectedFloor]!.map((room) => buildRoomCard(room)),
                const SizedBox(height: 80),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          height: 400,
          child: Column(
            children: [
              const Text(
                'เลือกชั้น',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    int floor = index + 1;
                    return ListTile(
                      leading: Icon(
                        Icons.layers,
                        color: selectedFloor == floor ? const Color(0xFF9A2C2C) : Colors.grey,
                      ),
                      title: Text(
                        'ชั้น $floor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: selectedFloor == floor ? FontWeight.bold : FontWeight.normal,
                          color: selectedFloor == floor ? const Color(0xFF9A2C2C) : Colors.black,
                        ),
                      ),
                      trailing: selectedFloor == floor
                          ? const Icon(Icons.check, color: Color(0xFF9A2C2C))
                          : null,
                      onTap: () {
                        setState(() {
                          selectedFloor = floor;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ฟังก์ชันแสดง Dialog เพิ่มห้อง
  void _showAddRoomDialog(BuildContext context) {
    final TextEditingController roomNameController = TextEditingController();
    int selectedFloorForNewRoom = selectedFloor;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('เพิ่มห้องใหม่', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ช่องกรอกชื่อห้อง
                  TextField(
                    controller: roomNameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อห้อง',
                      hintText: 'เช่น Room 1959',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.location_on, color: Color(0xFFD32F2F)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // เลือกชั้น
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: DropdownButton<int>(
                      value: selectedFloorForNewRoom,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9A2C2C)),
                      items: List.generate(6, (index) {
                        int floor = index + 1;
                        return DropdownMenuItem(
                          value: floor,
                          child: Text('ชั้น $floor', style: const TextStyle(fontSize: 16)),
                        );
                      }),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedFloorForNewRoom = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (roomNameController.text.isNotEmpty) {
                      setState(() {
                        floorRooms[selectedFloorForNewRoom]!.add(roomNameController.text);
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เพิ่ม ${roomNameController.text} ที่ชั้น $selectedFloorForNewRoom สำเร็จ'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('สร้าง', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildRoomCard(String roomName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const Icon(
          Icons.location_on,
          color: Color(0xFFD32F2F),
          size: 30,
        ),
        title: Text(
          roomName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ปุ่มลบ
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              onPressed: () => _showDeleteConfirmation(roomName),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
        onTap: () {
          // กดเข้าไปหน้ารายละเอียดห้อง
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KrupanRoomScreen(
                roomName: roomName,
                floor: selectedFloor,
              ),
            ),
          );
        },
      ),
    );
  }

  // ฟังก์ชัน Empty State เมื่อไม่มีข้อมูล
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            'ยังไม่มีห้องในชั้นนี้',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'กดปุ่ม + ด้านล่างเพื่อเพิ่มห้องครุภัณฑ์',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF9A2C2C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF9A2C2C), size: 20),
                SizedBox(width: 8),
                Text(
                  'เริ่มต้นจัดการครุภัณฑ์ได้เลย',
                  style: TextStyle(
                    color: Color(0xFF9A2C2C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันยืนยันการลบห้อง
  void _showDeleteConfirmation(String roomName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('ยืนยันการลบ', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Text(
            'คุณต้องการลบ "$roomName" ใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  floorRooms[selectedFloor]!.remove(roomName);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ลบ $roomName สำเร็จ'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
}