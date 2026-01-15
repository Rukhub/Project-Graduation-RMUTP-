import 'package:flutter/material.dart';
import 'krupan_room.dart'; // import ไฟล์หน้าห้อง
import 'data_service.dart';
import 'app_drawer.dart';

class KrupanScreen extends StatefulWidget {
  const KrupanScreen({super.key});

  @override
  State<KrupanScreen> createState() => _KrupanScreenState();
}

class _KrupanScreenState extends State<KrupanScreen> {
  // เก็บชั้นที่เลือกอยู่
  int selectedFloor = 1;
  final DataService _dataService = DataService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // ใช้ข้อมูลจาก DataService
    List<String> rooms = _dataService.floorRooms[selectedFloor] ?? [];

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
                // แสดงรายการห้องของชั้นที่เลือก
                ...rooms.map((room) => buildRoomCard(room)),
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
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'เลือกชั้น',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _dataService.floorRooms.keys.length,
                  itemBuilder: (context, index) {
                    // เรียงชั้นตาม Key
                    List<int> sortedFloors = _dataService.floorRooms.keys.toList()..sort();
                    int floor = sortedFloors[index];
                    return ListTile(
                      title: Text(
                        'ชั้น $floor',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: selectedFloor == floor
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selectedFloor == floor
                                ? const Color(0xFF9A2C2C)
                                : Colors.black),
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
              onPressed: () {
                if (roomController.text.isNotEmpty) {
                  setState(() {
                     _dataService.addRoom(selectedFloor, roomController.text);
                  });
                  Navigator.pop(context);
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
  Widget buildRoomCard(String roomName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KrupanRoomScreen(roomName: roomName, floor: selectedFloor),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9A2C2C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.meeting_room,
                    color: Color(0xFF9A2C2C),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Column(
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
                const Spacer(),
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
}