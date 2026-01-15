import 'package:flutter/material.dart';
import 'data_service.dart';

class AddEquipmentQuickScreen extends StatefulWidget {
  const AddEquipmentQuickScreen({super.key});

  @override
  State<AddEquipmentQuickScreen> createState() => _AddEquipmentQuickScreenState();
}

class _AddEquipmentQuickScreenState extends State<AddEquipmentQuickScreen> {
  // ชั้นที่เลือกอยู่
  int selectedFloor = 1;

  // ประเภทครุภัณฑ์
  List<Map<String, dynamic>> equipmentTypes = [
    {'name': 'หน้าจอ', 'icon': Icons.monitor, 'color': Color(0xFF5593E4)},
    {'name': 'PC', 'icon': Icons.computer, 'color': Color(0xFF99CD60)},
    {'name': 'เมาส์', 'icon': Icons.mouse, 'color': Color(0xFFFECC52)},
    {'name': 'คีย์บอร์ด', 'icon': Icons.keyboard, 'color': Color(0xFFE44F5A)},
  ];

  // รายการสถานะ
  List<Map<String, dynamic>> statusList = [
    {'name': 'ปกติ', 'color': Color(0xFF99CD60), 'icon': Icons.check_circle},
    {'name': 'ชำรุด', 'color': Color(0xFFE44F5A), 'icon': Icons.cancel},
    {'name': 'อยู่ระหว่างซ่อม', 'color': Color(0xFFFECC52), 'icon': Icons.build_circle},
  ];

  @override
  Widget build(BuildContext context) {
    var floorRooms = DataService().floorRooms;
    
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
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'เพิ่มอุปกรณ์',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        toolbarHeight: 80,
      ),
      body: Column(
        children: [
          // ส่วนเลือกชั้น
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เลือกห้องที่ต้องการเพิ่มอุปกรณ์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 15),
                // Dropdown เลือกชั้น
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DropdownButton<int>(
                    value: selectedFloor,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9A2C2C)),
                    items: List.generate(6, (index) {
                      int floor = index + 1;
                      int roomCount = floorRooms[floor]?.length ?? 0;
                      return DropdownMenuItem(
                        value: floor,
                        child: Row(
                          children: [
                            Icon(Icons.layers, color: const Color(0xFF9A2C2C), size: 22),
                            const SizedBox(width: 10),
                            Text('ชั้น $floor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9A2C2C).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$roomCount ห้อง',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9A2C2C)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedFloor = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // รายการห้อง
          Expanded(
            child: floorRooms[selectedFloor]!.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: floorRooms[selectedFloor]!.length,
                    itemBuilder: (context, index) {
                      String roomName = floorRooms[selectedFloor]![index];
                      return _buildRoomCard(roomName);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Card ห้อง
  Widget _buildRoomCard(String roomName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAddEquipmentDialog(roomName),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9A2C2C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.meeting_room, color: Color(0xFF9A2C2C), size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ชั้น $selectedFloor',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF99CD60).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Color(0xFF99CD60), size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            'ไม่มีห้องในชั้นนี้',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'กรุณาเลือกชั้นอื่น',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog เพิ่มครุภัณฑ์
  void _showAddEquipmentDialog(String roomName) {
    final TextEditingController idController = TextEditingController();
    String selectedType = equipmentTypes.first['name'] as String;
    String selectedStatus = 'ปกติ';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.add_circle_outline, color: Color(0xFF9A2C2C), size: 28),
                      SizedBox(width: 10),
                      Text('เพิ่มครุภัณฑ์ใหม่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9A2C2C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room, size: 16, color: Color(0xFF9A2C2C)),
                        const SizedBox(width: 6),
                        Text(
                          '$roomName • ชั้น $selectedFloor',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF9A2C2C), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // รหัสครุภัณฑ์
                    TextField(
                      controller: idController,
                      decoration: InputDecoration(
                        labelText: 'รหัสครุภัณฑ์',
                        hintText: 'เช่น 1-104-7440-006-0006/013-67',
                        prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF9A2C2C)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9A2C2C), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ประเภท
                    Text('ประเภท', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9A2C2C)),
                        items: equipmentTypes.map((type) {
                          return DropdownMenuItem(
                            value: type['name'] as String,
                            child: Row(
                              children: [
                                Icon(type['icon'] as IconData, size: 20, color: type['color'] as Color),
                                const SizedBox(width: 10),
                                Text(type['name'] as String, style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedType = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // สถานะ
                    Text('สถานะ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusList.map((status) {
                        final isSelected = selectedStatus == status['name'];
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedStatus = status['name'] as String;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? (status['color'] as Color).withOpacity(0.2) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? status['color'] as Color : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(status['icon'] as IconData, size: 18, color: status['color'] as Color),
                                const SizedBox(width: 6),
                                Text(
                                  status['name'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: status['color'] as Color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (idController.text.isNotEmpty) {
                      // บันทึกลง DataService
                      DataService().addEquipment(roomName, {
                        'id': idController.text,
                        'type': selectedType,
                        'status': selectedStatus,
                        // Add empty defaults
                        'images': [],
                        'inspectorName': null,
                        'reporterName': null,
                        'reportReason': null,
                        'inspectorImages': [],
                        'reportImages': [],
                      });
                      
                      Navigator.pop(context); // ปิด Dialog
                      Navigator.pop(context); // กลับหน้า Menu
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เพิ่ม ${idController.text} ที่ $roomName สำเร็จ'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('เพิ่ม', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
