import 'package:flutter/material.dart';
import 'equipment_detail_screen.dart';  // เพิ่มบรรทัดนี้

class KrupanRoomScreen extends StatefulWidget {
  final String roomName;
  final int floor;

  const KrupanRoomScreen({
    super.key,
    required this.roomName,
    required this.floor,
  });

  @override
  State<KrupanRoomScreen> createState() => _KrupanRoomScreenState();
}

class _KrupanRoomScreenState extends State<KrupanRoomScreen> {
  // เก็บข้อมูลครุภัณฑ์ในห้อง
  List<Map<String, dynamic>> equipmentList = [];
  
  // รายการประเภทครุภัณฑ์ที่สามารถเพิ่ม/ลบได้
  List<Map<String, dynamic>> equipmentTypes = [
    {'name': 'หน้าจอ', 'icon': Icons.monitor, 'color': Color(0xFF5593E4)},
    {'name': 'PC', 'icon': Icons.computer, 'color': Color(0xFF99CD60)},
    {'name': 'เมาส์', 'icon': Icons.mouse, 'color': Color(0xFFFECC52)},
    {'name': 'คีย์บอร์ด', 'icon': Icons.keyboard, 'color': Color(0xFFE44F5A)},
  ];

  // ฟังก์ชันคำนวณจำนวนครุภัณฑ์ทั้งหมด
  int get totalEquipmentQuantity {
    return equipmentList.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }

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
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.roomName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'ชั้น ${widget.floor}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ข้อมูลห้อง
          _buildInfoCard(
            icon: Icons.location_on,
            title: 'ชื่อห้อง',
            value: widget.roomName,
            color: const Color(0xFFD32F2F),
          ),
          _buildInfoCard(
            icon: Icons.layers,
            title: 'ชั้น',
            value: 'ชั้น ${widget.floor}',
            color: const Color(0xFF9A2C2C),
          ),
          _buildInfoCard(
            icon: Icons.inventory_2,
            title: 'จำนวนครุภัณฑ์',
            value: '$totalEquipmentQuantity ชิ้น (${equipmentList.length} รายการ)',
            color: const Color(0xFF5593E4),
          ),
          const SizedBox(height: 25),

          // หัวข้อรายการครุภัณฑ์
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รายการครุภัณฑ์',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9A2C2C).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalEquipmentQuantity ชิ้น',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9A2C2C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // แสดงรายการครุภัณฑ์ หรือ Empty State
          equipmentList.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: equipmentList
                      .asMap()
                      .entries
                      .map((entry) => _buildEquipmentCard(entry.key, entry.value))
                      .toList(),
                ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ปุ่มจัดการประเภทครุภัณฑ์
          SizedBox(
            width: 56,
            height: 56,
            child: FloatingActionButton(
              onPressed: () => _showManageTypesDialog(),
              backgroundColor: const Color(0xFF5593E4),
              heroTag: 'manage_types',
              child: const Icon(Icons.settings, size: 28, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          // ปุ่มเพิ่มครุภัณฑ์
          SizedBox(
            width: 70,
            height: 70,
            child: FloatingActionButton(
              onPressed: () => _showAddEquipmentDialog(),
              backgroundColor: const Color(0xFF9A2C2C),
              heroTag: 'add_equipment',
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 40, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Card ข้อมูลห้อง
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card ครุภัณฑ์แต่ละรายการ
  Widget _buildEquipmentCard(int index, Map<String, dynamic> equipment) {
    // หา icon และ color จากประเภทที่เลือก
    var typeData = equipmentTypes.firstWhere(
      (type) => type['name'] == equipment['type'],
      orElse: () => {'name': 'อื่นๆ', 'icon': Icons.devices_other, 'color': Colors.grey},
    );

    IconData equipmentIcon = typeData['icon'] as IconData;
    Color equipmentColor = typeData['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EquipmentDetailScreen(
                equipment: {
                  ...equipment,
                  'id': 'EQ${(index + 1).toString().padLeft(4, '0')}',
                },
                roomName: widget.roomName,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: equipmentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(equipmentIcon, color: equipmentColor, size: 26),
        ),
        title: Text(
          equipment['name'],
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.category, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              Text(
                equipment['type'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 15),
              Icon(Icons.numbers, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              Text(
                'จำนวน: ${equipment['quantity']}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ปุ่มแก้ไข
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF5593E4), size: 22),
              onPressed: () => _showEditEquipmentDialog(index, equipment),
            ),
            // ปุ่มลบ
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              onPressed: () => _showDeleteConfirmation(index, equipment['name']),
            ),
          ],
        ),
      ),
    );
  }

  // Empty State เมื่อไม่มีครุภัณฑ์
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 90,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            'ยังไม่มีครุภัณฑ์ในห้องนี้',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'กดปุ่ม + ด้านล่างเพื่อเพิ่มครุภัณฑ์',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF9A2C2C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF9A2C2C).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, color: Color(0xFF9A2C2C), size: 20),
                SizedBox(width: 10),
                Text(
                  'เริ่มต้นเพิ่มครุภัณฑ์เลย',
                  style: TextStyle(
                    color: Color(0xFF9A2C2C),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dialog จัดการประเภทครุภัณฑ์
  void _showManageTypesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.settings, color: Color(0xFF5593E4), size: 28),
                  SizedBox(width: 10),
                  Text('จัดการประเภทครุภัณฑ์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: equipmentTypes.length,
                        itemBuilder: (context, index) {
                          final type = equipmentTypes[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Icon(
                                type['icon'] as IconData,
                                color: type['color'] as Color,
                              ),
                              title: Text(type['name'] as String),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    equipmentTypes.removeAt(index);
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddTypeDialog();
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('เพิ่มประเภทใหม่', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5593E4),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด', style: TextStyle(color: Color(0xFF5593E4), fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog เพิ่มประเภทครุภัณฑ์ใหม่
  void _showAddTypeDialog() {
    final TextEditingController typeNameController = TextEditingController();
    IconData selectedIcon = Icons.devices_other;
    Color selectedColor = const Color(0xFF9A2C2C);

    // ไอคอนที่เลือกได้
    final List<IconData> availableIcons = [
      Icons.devices_other,
      Icons.headphones,
      Icons.chair,
      Icons.table_bar,
      Icons.lightbulb,
      Icons.cable,
      Icons.speaker,
      Icons.print,
      Icons.router,
      Icons.camera,
      Icons.electric_bolt,
      Icons.air,
    ];

    // สีที่เลือกได้
    final List<Color> availableColors = [
      const Color(0xFF9A2C2C),
      const Color(0xFF5593E4),
      const Color(0xFF99CD60),
      const Color(0xFFFECC52),
      const Color(0xFFE44F5A),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF9800),
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.add_circle, color: Color(0xFF5593E4), size: 28),
                  SizedBox(width: 10),
                  Text('เพิ่มประเภทครุภัณฑ์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ชื่อประเภท
                    TextField(
                      controller: typeNameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อประเภท',
                        hintText: 'เช่น หูฟัง, โต๊ะ, เก้าอี้',
                        prefixIcon: const Icon(Icons.edit, color: Color(0xFF5593E4)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF5593E4), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // เลือกไอคอน
                    Text('เลือกไอคอน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableIcons.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? selectedColor.withOpacity(0.2) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? selectedColor : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(icon, color: isSelected ? selectedColor : Colors.grey.shade600, size: 28),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // เลือกสี
                    Text('เลือกสี', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableColors.map((color) {
                        final isSelected = color == selectedColor;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
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
                    if (typeNameController.text.isNotEmpty) {
                      setState(() {
                        equipmentTypes.add({
                          'name': typeNameController.text,
                          'icon': selectedIcon,
                          'color': selectedColor,
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เพิ่มประเภท "${typeNameController.text}" สำเร็จ'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5593E4),
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

  // Dialog เพิ่มครุภัณฑ์
  void _showAddEquipmentDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '1');
    String selectedType = equipmentTypes.first['name'] as String;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.add_circle_outline, color: Color(0xFF9A2C2C), size: 28),
                  SizedBox(width: 10),
                  Text('เพิ่มครุภัณฑ์ใหม่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ชื่อครุภัณฑ์
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อครุภัณฑ์',
                        hintText: 'เช่น Monitor Dell 24"',
                        prefixIcon: const Icon(Icons.edit, color: Color(0xFF9A2C2C)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9A2C2C), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ประเภท
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
                                Icon(
                                  type['icon'] as IconData,
                                  size: 20,
                                  color: type['color'] as Color,
                                ),
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

                    // จำนวน
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'จำนวน',
                        hintText: '1',
                        prefixIcon: const Icon(Icons.format_list_numbered, color: Color(0xFF9A2C2C)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9A2C2C), width: 2),
                        ),
                      ),
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
                    if (nameController.text.isNotEmpty) {
                      setState(() {
                        equipmentList.add({
                          'name': nameController.text,
                          'type': selectedType,
                          'quantity': int.tryParse(quantityController.text) ?? 1,
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เพิ่ม ${nameController.text} สำเร็จ'),
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

 // Dialog แก้ไขครุภัณฑ์
  void _showEditEquipmentDialog(int index, Map<String, dynamic> equipment) {
    final TextEditingController nameController = TextEditingController(text: equipment['name']);
    final TextEditingController quantityController = TextEditingController(text: equipment['quantity'].toString());
    String selectedType = equipment['type'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.edit, color: Color(0xFF5593E4), size: 28),
                  SizedBox(width: 10),
                  Text('แก้ไขครุภัณฑ์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ชื่อครุภัณฑ์
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อครุภัณฑ์',
                        hintText: 'เช่น Monitor Dell 24"',
                        prefixIcon: const Icon(Icons.edit, color: Color(0xFF5593E4)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF5593E4), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ประเภท
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
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF5593E4)),
                        items: equipmentTypes.map((type) {
                          return DropdownMenuItem(
                            value: type['name'] as String,
                            child: Row(
                              children: [
                                Icon(
                                  type['icon'] as IconData,
                                  size: 20,
                                  color: type['color'] as Color,
                                ),
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

                    // จำนวน
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'จำนวน',
                        hintText: '1',
                        prefixIcon: const Icon(Icons.format_list_numbered, color: Color(0xFF5593E4)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF5593E4), width: 2),
                        ),
                      ),
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
                    if (nameController.text.isNotEmpty) {
                      setState(() {
                        equipmentList[index] = {
                          'name': nameController.text,
                          'type': selectedType,
                          'quantity': int.tryParse(quantityController.text) ?? 1,
                        };
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('แก้ไข ${nameController.text} สำเร็จ'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5593E4),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('บันทึก', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog ยืนยันการลบ
  void _showDeleteConfirmation(int index, String equipmentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text('ยืนยันการลบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: Text(
            'คุณต้องการลบ "$equipmentName" ใช่หรือไม่?',
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
                  equipmentList.removeAt(index);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ลบ $equipmentName สำเร็จ'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ลบ', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }
}