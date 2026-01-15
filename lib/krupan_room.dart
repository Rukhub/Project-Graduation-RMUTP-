import 'package:flutter/material.dart';
import 'equipment_detail_screen.dart';
import 'report_problem_screen.dart';
import 'inspect_equipment_screen.dart';
import 'data_service.dart';
import 'api_service.dart'; // import api_service
import 'app_drawer.dart';

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
  // เก็บข้อมูลครุภัณฑ์ในห้อง (ตอนนี้ดึงจาก DataService)
  List<Map<String, dynamic>> equipmentList = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // โหลดข้อมูลจาก API จริง
    final assets = await ApiService().getAssets();
    
    // ถ้ามีข้อมูลจาก API ให้ใช้ข้อมูลนั้น
    if (assets.isNotEmpty) {
      setState(() {
        equipmentList = assets;
      });
    } else {
      // Fallback: ถ้า API ยังไม่มีข้อมูล หรือ error ให้ลองใช้ข้อมูลเก่าไปก่อน (Optional)
      // หรือปล่อยว่างไว้
      setState(() {
        equipmentList = [];
      });
    }
  }
  
  // Filter ที่เลือก
  String selectedTypeFilter = 'ทั้งหมด';
  String selectedStatusFilter = 'ทั้งหมด';
  
  // รายการประเภทครุภัณฑ์
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

  // กรองครุภัณฑ์ตาม Filter
  List<Map<String, dynamic>> get filteredEquipmentList {
    return equipmentList.where((item) {
      bool matchType = selectedTypeFilter == 'ทั้งหมด' || item['type'] == selectedTypeFilter;
      bool matchStatus = selectedStatusFilter == 'ทั้งหมด' || item['status'] == selectedStatusFilter;
      return matchType && matchStatus;
    }).toList();
  }

  // จำนวนครุภัณฑ์ทั้งหมด
  int get totalEquipmentCount => equipmentList.length;

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
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
            value: '$totalEquipmentCount ชิ้น',
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
                  '${filteredEquipmentList.length} ชิ้น',
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

          // Filter ประเภท
          _buildFilterSection(),
          const SizedBox(height: 15),

          // แสดงรายการครุภัณฑ์ หรือ Empty State
          filteredEquipmentList.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: filteredEquipmentList
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

  // ส่วน Filter (Dropdown)
  Future<void> _navigateToReport(int index, Map<String, dynamic> equipment) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ReportProblemScreen(
          equipment: equipment,
          roomName: widget.roomName,
        ),
      ),
    );

    if (result != null) {
      _updateEquipmentState(index, result);
    }
  }

  Future<void> _navigateToInspect(int index, Map<String, dynamic> equipment) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => InspectEquipmentScreen(
          equipment: equipment,
          roomName: widget.roomName,
        ),
      ),
    );

    if (result != null) {
      _updateEquipmentState(index, result);
    }
  }

  void _updateEquipmentState(int index, Map<String, dynamic> result) {
    setState(() {
      Map<String, dynamic> item = equipmentList[index];
      
      if (result['status'] != null) item['status'] = result['status'];
      if (result['inspectorName'] != null) item['inspectorName'] = result['inspectorName'];
      if (result['inspectorImages'] != null) item['inspectorImages'] = result['inspectorImages'];
      
      // อัปเดตข้อมูลผู้แจ้ง
      if (result['reporterName'] != null) {
        item['reporterName'] = result['reporterName'];
      } else if (result.containsKey('reporterName')) {
        item['reporterName'] = null;
      }
      
      if (result['reportReason'] != null) {
        item['reportReason'] = result['reportReason'];
      } else if (result.containsKey('reportReason')) {
        item['reportReason'] = null;
      }
      
      if (result['reportImages'] != null) {
        item['reportImages'] = result['reportImages'];
      } else if (result.containsKey('reportImages')) {
        item['reportImages'] = [];
      }
      
      // บันทึกลง Global DataService
      DataService().updateEquipment(widget.roomName, item);
    });
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Dropdown ประเภท
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ประเภท',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selectedTypeFilter,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9A2C2C)),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: [
                      const DropdownMenuItem(value: 'ทั้งหมด', child: Text('ทั้งหมด')),
                      ...equipmentTypes.map((type) => DropdownMenuItem(
                        value: type['name'] as String,
                        child: Row(
                          children: [
                            Icon(type['icon'] as IconData, size: 18, color: type['color'] as Color),
                            const SizedBox(width: 8),
                            Text(type['name'] as String),
                          ],
                        ),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => selectedTypeFilter = value!);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Dropdown สถานะ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สถานะ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selectedStatusFilter,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9A2C2C)),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: [
                      const DropdownMenuItem(value: 'ทั้งหมด', child: Text('ทั้งหมด')),
                      ...statusList.map((status) => DropdownMenuItem(
                        value: status['name'] as String,
                        child: Row(
                          children: [
                            Icon(status['icon'] as IconData, size: 18, color: status['color'] as Color),
                            const SizedBox(width: 8),
                            Text(status['name'] as String),
                          ],
                        ),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => selectedStatusFilter = value!);
                    },
                  ),
                ),
              ],
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

    // หา status color
    var statusData = statusList.firstWhere(
      (status) => status['name'] == equipment['status'],
      orElse: () => {'name': 'ปกติ', 'color': Color(0xFF99CD60), 'icon': Icons.check_circle},
    );
    Color statusColor = statusData['color'] as Color;
    IconData statusIcon = statusData['icon'] as IconData;

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
        onTap: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => EquipmentDetailScreen(
                equipment: equipment,
                roomName: widget.roomName,
              ),
            ),
          );
          // ถ้ามีการเปลี่ยนแปลง อัปเดตข้อมูลทั้งหมด
          if (result != null) {
            int realIndex = equipmentList.indexWhere((item) => item['id'] == equipment['id']);
            if (realIndex != -1) {
              setState(() {
                if (result['status'] != null) {
                  equipmentList[realIndex]['status'] = result['status'];
                }
                if (result['inspectorName'] != null) {
                  equipmentList[realIndex]['inspectorName'] = result['inspectorName'];
                }
                if (result['inspectorImages'] != null) {
                  equipmentList[realIndex]['inspectorImages'] = result['inspectorImages'];
                }
                if (result['reporterName'] != null) {
                  equipmentList[realIndex]['reporterName'] = result['reporterName'];
                } else if (result.containsKey('reporterName')) {
                  equipmentList[realIndex]['reporterName'] = null;
                }
                if (result['reportReason'] != null) {
                  equipmentList[realIndex]['reportReason'] = result['reportReason'];
                } else if (result.containsKey('reportReason')) {
                  equipmentList[realIndex]['reportReason'] = null;
                }
                if (result['reportImages'] != null) {
                  equipmentList[realIndex]['reportImages'] = result['reportImages'];
                }
              });
            }
          }
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
          equipment['id'] ?? 'ไม่ระบุรหัส',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.category, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    equipment['type'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // แสดงสถานะ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      equipment['status'] ?? 'ปกติ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ปุ่มแจ้งปัญหา
            IconButton(
              tooltip: 'แจ้งปัญหา',
              icon: Icon(Icons.report_problem_outlined, color: Colors.orange.shade700, size: 22),
              onPressed: () => _navigateToReport(index, equipment),
            ),
             // ปุ่มตรวจสอบ
            IconButton(
              tooltip: 'ตรวจสอบ',
              icon: const Icon(Icons.verified_outlined, color: Colors.green, size: 22),
              onPressed: () => _navigateToInspect(index, equipment),
            ),
            // ปุ่มแก้ไข
            IconButton(
              tooltip: 'แก้ไข',
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF5593E4), size: 22),
              onPressed: () => _showEditEquipmentDialog(index, equipment),
            ),
            // ปุ่มลบ
            IconButton(
              tooltip: 'ลบ',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              onPressed: () => _showDeleteConfirmation(index, equipment['id'] ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  // Empty State เมื่อไม่มีครุภัณฑ์
  Widget _buildEmptyState() {
    String emptyMessage = 'ยังไม่มีครุภัณฑ์ในห้องนี้';
    if (selectedTypeFilter != 'ทั้งหมด' || selectedStatusFilter != 'ทั้งหมด') {
      emptyMessage = 'ไม่พบครุภัณฑ์ตาม Filter ที่เลือก';
    }
    
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
            emptyMessage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            equipmentList.isEmpty ? 'กดปุ่ม + ด้านล่างเพื่อเพิ่มครุภัณฑ์' : 'ลองเปลี่ยน Filter ดู',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (equipmentList.isEmpty) ...[
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // รหัสครุภัณฑ์
                    TextField(
                      controller: idController,
                      decoration: InputDecoration(
                        labelText: 'รหัสครุภัณฑ์',
                        hintText: 'เช่น 1-104-7440-006-0006/013-67',
                        prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF9A2C2C)),
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
                      setState(() {
                        equipmentList.add({
                          'id': idController.text,
                          'type': selectedType,
                          'status': selectedStatus,
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เพิ่ม ${idController.text} สำเร็จ'),
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
    final TextEditingController idController = TextEditingController(text: equipment['id']);
    String selectedType = equipment['type'] as String;
    String selectedStatus = equipment['status'] ?? 'ปกติ';

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // รหัสครุภัณฑ์
                    TextField(
                      controller: idController,
                      decoration: InputDecoration(
                        labelText: 'รหัสครุภัณฑ์',
                        prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF5593E4)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF5593E4), width: 2),
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
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF5593E4)),
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
                      // หา index จริงใน equipmentList
                      int realIndex = equipmentList.indexWhere((item) => item['id'] == equipment['id']);
                      if (realIndex != -1) {
                        setState(() {
                          equipmentList[realIndex] = {
                            'id': idController.text,
                            'type': selectedType,
                            'status': selectedStatus,
                          };
                        });
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('แก้ไขสำเร็จ'),
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
                  child: const Text('บันทึก', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog ยืนยันลบ
  void _showDeleteConfirmation(int index, String id) {
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
            'คุณต้องการลบ\n"$id"\nใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                // หา index จริงใน equipmentList
                int realIndex = equipmentList.indexWhere((item) => item['id'] == id);
                if (realIndex != -1) {
                  setState(() {
                    equipmentList.removeAt(realIndex);
                  });
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ลบ $id สำเร็จ'),
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