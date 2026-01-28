import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'equipment_detail_screen.dart';
import 'report_problem_screen.dart';
import 'inspect_equipment_screen.dart';

import 'api_service.dart'; // import api_service
import 'app_drawer.dart';

class KrupanRoomScreen extends StatefulWidget {
  final String roomName;
  final int floor;
  final int locationId; // รับ locationId เพื่อดึงข้อมูล

  const KrupanRoomScreen({
    super.key,
    required this.roomName,
    required this.floor,
    required this.locationId,
  });

  @override
  State<KrupanRoomScreen> createState() => _KrupanRoomScreenState();
}

class _KrupanRoomScreenState extends State<KrupanRoomScreen> {
  // เก็บข้อมูลครุภัณฑ์ในห้อง
  List<Map<String, dynamic>> equipmentList = [];
  bool isLoading = true; // สถานะโหลดข้อมูล
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filter ที่เลือก
  String selectedTypeFilter = 'ทั้งหมด';
  String selectedStatusFilter = 'ทั้งหมด';

  // รายการสถานะ
  List<Map<String, dynamic>> statusList = [
    {'name': 'ปกติ', 'color': Color(0xFF99CD60), 'icon': Icons.check_circle},
    {'name': 'ชำรุด', 'color': Color(0xFFE44F5A), 'icon': Icons.cancel},
    {
      'name': 'อยู่ระหว่างซ่อม',
      'color': Color(0xFFFECC52),
      'icon': Icons.build_circle,
    },
  ];

  // รายการประเภทครุภัณฑ์ (Initial) - จะถูกอัปเดตถ้ามีประเภทใหม่จาก DB
  List<Map<String, dynamic>> equipmentTypes = [
    {'name': 'หน้าจอ', 'icon': Icons.monitor, 'color': Color(0xFF5593E4)},
    {'name': 'เคสคอม', 'icon': Icons.storage, 'color': Color(0xFF99CD60)},
    {'name': 'เมาส์', 'icon': Icons.mouse, 'color': Color(0xFFFECC52)},
    {'name': 'คีย์บอร์ด', 'icon': Icons.keyboard, 'color': Color(0xFFE44F5A)},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    // โหลดข้อมูลจาก API โดยใช้ locationId
    final assets = await ApiService().getAssetsByLocation(widget.locationId);

    // 🔍 DEBUG: ดูว่า API ส่งอะไรมา
    print(
      '🔍 DEBUG: API returned ${assets.length} items for location ${widget.locationId}',
    );
    print(
      '🔍 DEBUG: First item = ${assets.isNotEmpty ? assets.first : "EMPTY"}',
    );

    setState(() {
      equipmentList = assets.map((item) {
        // Sanitization & Mapping: แปลงข้อมูลจาก API ให้ตรงกับที่แอปใช้
        final sanitizedItem = Map<String, dynamic>.from(item);

        // 1. ID Converstion
        sanitizedItem['id'] = item['id']?.toString();
        sanitizedItem['asset_id'] = item['asset_id']?.toString();
        sanitizedItem['location_id'] = item['location_id']?.toString();

        // 2. Column Mapping (API -> App)
        // API ส่ง 'asset_type' -> App ใช้ 'type'
        if (item.containsKey('asset_type')) {
          sanitizedItem['type'] = item['asset_type']?.toString();
        } else {
          sanitizedItem['type'] = item['type']?.toString();
        }

        // API ส่ง 'checker_name' -> App ใช้ 'inspectorName'
        if (item.containsKey('checker_name')) {
          sanitizedItem['inspectorName'] = item['checker_name']?.toString();
        }

        // 3. Status Mapping
        // ถ้า API ส่งสถานะที่ไม่คุ้นเคย มาแปลงให้เข้ากับระบบ
        String status = item['status']?.toString() ?? 'ปกติ';
        if (status == 'ตรวจสอบแล้ว') {
          status = 'ปกติ'; // ถือว่าปกติ
        } else if (status == 'ไม่ได้ตรวจสอบ') {
          status = 'ปกติ'; // Default ไปก่อน
        }
        sanitizedItem['status'] = status;

        // 4. Image Handling
        // API ส่ง 'image_url' (String) -> App ใช้ 'images' (List<String>)
        if (item['image_url'] != null &&
            item['image_url'].toString().isNotEmpty) {
          sanitizedItem['images'] = [item['image_url'].toString()];
        } else {
          sanitizedItem['images'] = [];
        }

        return sanitizedItem;
      }).toList();
      isLoading = false;
    });
  }

  // กรองครุภัณฑ์ตาม Filter
  List<Map<String, dynamic>> get filteredEquipmentList {
    return equipmentList.where((item) {
      bool matchType =
          selectedTypeFilter == 'ทั้งหมด' || item['type'] == selectedTypeFilter;
      bool matchStatus =
          selectedStatusFilter == 'ทั้งหมด' ||
          item['status'] == selectedStatusFilter;
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
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Color(0xFF9A2C2C),
            ),
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
              style: const TextStyle(fontSize: 14, color: Colors.white70),
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF9A2C2C)),
            )
          : ListView(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9A2C2C).withValues(alpha: 0.15),
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
                            .map(
                              (entry) =>
                                  _buildEquipmentCard(entry.key, entry.value),
                            )
                            .toList(),
                      ),
                const SizedBox(height: 140),
              ],
            ),
      floatingActionButton: ApiService().currentUser?['role'] == 'admin'
          ? Column(
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
                    child: const Icon(
                      Icons.settings,
                      size: 28,
                      color: Colors.white,
                    ),
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
            )
          : null,
    );
  }

  // ส่วน Filter (Dropdown)
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF9A2C2C),
                    ),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: [
                      const DropdownMenuItem(
                        value: 'ทั้งหมด',
                        child: Text('ทั้งหมด'),
                      ),
                      ...equipmentTypes.map(
                        (type) => DropdownMenuItem(
                          value: type['name'] as String,
                          child: Row(
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 18,
                                color: type['color'] as Color,
                              ),
                              const SizedBox(width: 8),
                              Text(type['name'] as String),
                            ],
                          ),
                        ),
                      ),
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
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF9A2C2C),
                    ),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: [
                      const DropdownMenuItem(
                        value: 'ทั้งหมด',
                        child: Text('ทั้งหมด'),
                      ),
                      ...statusList.map(
                        (status) => DropdownMenuItem(
                          value: status['name'] as String,
                          child: Row(
                            children: [
                              Icon(
                                status['icon'] as IconData,
                                size: 18,
                                color: status['color'] as Color,
                              ),
                              const SizedBox(width: 8),
                              Text(status['name'] as String),
                            ],
                          ),
                        ),
                      ),
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
            color: Colors.black.withValues(alpha: 0.05),
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
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
      orElse: () => {
        'name': 'อื่นๆ',
        'icon': Icons.devices_other,
        'color': Colors.grey,
      },
    );

    IconData equipmentIcon = typeData['icon'] as IconData;
    Color equipmentColor = typeData['color'] as Color;

    // หา status color
    var statusData = statusList.firstWhere(
      (status) => status['name'] == equipment['status'],
      orElse: () => {
        'name': 'ปกติ',
        'color': Color(0xFF99CD60),
        'icon': Icons.check_circle,
      },
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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
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
          if (result != null) {
            _updateLocalItem(equipment['id']?.toString() ?? '', result);
            await _loadData(); // Ensure full sync with API
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: equipmentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(equipmentIcon, color: equipmentColor, size: 24),
              ),
              const SizedBox(width: 12),

              // Content (Title + Subtitle)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (equipment['asset_id'] ??
                              equipment['id'] ??
                              'ไม่ระบุรหัส')
                          .toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          // Ensure text doesn't overflow here too
                          child: Text(
                            (equipment['type'] ?? '-').toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            (equipment['status'] ?? 'ปกติ').toString(),
                            style: TextStyle(
                              fontSize: 11,
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

              // Actions (Compact)
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Admin View: Full Controls
                  if (ApiService().currentUser?['role'] == 'admin') ...[
                    _buildCompactAssetButton(
                      icon: Icons.report_problem_outlined,
                      color: Colors.orange.shade700,
                      tooltip: 'แจ้งปัญหา',
                      onPressed: () => _navigateToReport(index, equipment),
                    ),
                    _buildCompactAssetButton(
                      icon: Icons.verified_outlined,
                      color: Colors.green,
                      tooltip: 'ตรวจสอบ',
                      onPressed: () => _navigateToInspect(index, equipment),
                    ),
                    _buildCompactAssetButton(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF5593E4),
                      tooltip: 'แก้ไข',
                      onPressed: () =>
                          _showEditEquipmentDialog(index, equipment),
                    ),
                    _buildCompactAssetButton(
                      icon: Icons.delete_outline,
                      color: Colors.redAccent,
                      tooltip: 'ลบ',
                      onPressed: () => _showDeleteConfirmation(
                        index,
                        (equipment['asset_id'] ?? equipment['id']).toString(),
                      ),
                    ),
                  ]
                  // User View: Simple Report Button
                  else
                    TextButton.icon(
                      onPressed: () => _navigateToReport(index, equipment),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: Icon(
                        Icons.report_problem,
                        size: 18,
                        color: Colors.orange.shade800,
                      ),
                      label: Text(
                        'แจ้งปัญหา',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAssetButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: 20),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4), // Reduce Padding
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ), // Reduce Hit Area constraints visually
      onPressed: onPressed,
    );
  }

  // Update logic for Report/Inspect
  Future<void> _navigateToReport(
    int index,
    Map<String, dynamic> equipment,
  ) async {
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
      _updateLocalItem(equipment['id'].toString(), result);
      await _loadData(); // Refresh list
    }
  }

  Future<void> _navigateToInspect(
    int index,
    Map<String, dynamic> equipment,
  ) async {
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
      _updateLocalItem(equipment['id'].toString(), result);
      await _loadData(); // Refresh list
    }
  }

  void _updateLocalItem(String id, Map<String, dynamic> changes) {
    setState(() {
      int idx = equipmentList.indexWhere((e) => e['id'].toString() == id);
      if (idx != -1) {
        // Map keys to match local format
        if (changes.containsKey('checkerName')) {
          changes['inspectorName'] = changes['checkerName'];
        }
        if (changes.containsKey('reporterName')) {
          changes['reporterName'] = changes['reporterName']; // Confirm key
        }

        equipmentList[idx].addAll(changes);
      }
    });
  }

  // Dialog จัดการประเภทครุภัณฑ์
  void _showManageTypesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.settings, color: Color(0xFF5593E4), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'จัดการประเภทครุภัณฑ์',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
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
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
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
                      label: const Text(
                        'เพิ่มประเภทใหม่',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5593E4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(color: Color(0xFF5593E4), fontSize: 16),
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.add_circle, color: Color(0xFF5593E4), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'เพิ่มประเภทครุภัณฑ์',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
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
                        prefixIcon: const Icon(
                          Icons.edit,
                          color: Color(0xFF5593E4),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF5593E4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'เลือกไอคอน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
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
                              color: isSelected
                                  ? selectedColor.withValues(alpha: 0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? selectedColor
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? selectedColor
                                  : Colors.grey.shade600,
                              size: 28,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'เลือกสี',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
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
                                color: isSelected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
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
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
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
                      _showCustomSnackBar(
                        'เพิ่มประเภท "${typeNameController.text}" สำเร็จ',
                        isSuccess: true,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5593E4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'เพิ่ม',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
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
    final TextEditingController brandController = TextEditingController();
    String selectedType = equipmentTypes.isNotEmpty
        ? equipmentTypes[0]['name'] as String
        : 'ทั่วไป';
    String selectedStatus = 'ปกติ';
    bool isSaving = false;

    // Image upload state
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.add_circle, color: Color(0xFF9A2C2C), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'เพิ่มครุภัณฑ์ใหม่',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // ⭐ ใช้ stretch ให้สม่ำเสมอ
                  children: [
                    TextField(
                      controller: idController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'รหัสครุภัณฑ์ (Asset ID)',
                        prefixIcon: const Icon(
                          Icons.qr_code,
                          color: Color(0xFF9A2C2C),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF9A2C2C),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: brandController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'ยี่ห้อ/รุ่น (Brand/Model)',
                        prefixIcon: const Icon(
                          Icons.branding_watermark,
                          color: Color(0xFF9A2C2C),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF9A2C2C),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'ประเภท',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
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
                        items: equipmentTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type['name'] as String,
                                child: Text(type['name'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) =>
                                  setDialogState(() => selectedType = value!),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'สถานะ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusList.map((status) {
                        final isSelected = selectedStatus == status['name'];
                        return InkWell(
                          onTap: isSaving
                              ? null
                              : () => setDialogState(
                                  () =>
                                      selectedStatus = status['name'] as String,
                                ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (status['color'] as Color).withValues(
                                      alpha: 0.2,
                                    )
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? status['color'] as Color
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status['icon'] as IconData,
                                  size: 18,
                                  color: status['color'] as Color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  status['name'] as String,
                                  style: TextStyle(
                                    color: status['color'] as Color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Image Picker Section
                    Text(
                      'รูปภาพครุภัณฑ์',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: isSaving
                            ? null
                            : () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) {
                                    return SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.camera_alt,
                                              color: Color(0xFF5593E4),
                                            ),
                                            title: const Text('ถ่ายรูป'),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              final XFile? photo = await picker
                                                  .pickImage(
                                                    source: ImageSource.camera,
                                                  );
                                              if (photo != null) {
                                                setDialogState(() {
                                                  selectedImage = File(
                                                    photo.path,
                                                  );
                                                });
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.photo_library,
                                              color: Color(0xFF99CD60),
                                            ),
                                            title: const Text(
                                              'เลือกจาก Gallery',
                                            ),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              final XFile? image = await picker
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                  );
                                              if (image != null) {
                                                setDialogState(() {
                                                  selectedImage = File(
                                                    image.path,
                                                  );
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              selectedImage = null;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 32,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'เพิ่มรูปภาพ\n(ไม่บังคับ)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (idController.text.isNotEmpty) {
                            setDialogState(() => isSaving = true);

                            String imageUrl = '';
                            if (selectedImage != null) {
                              final uploadedUrl = await ApiService()
                                  .uploadImage(selectedImage!);
                              if (uploadedUrl != null) {
                                imageUrl = uploadedUrl;
                              } else {
                                if (context.mounted) {
                                  _showCustomSnackBar(
                                    'อัปโหลดรูปภาพไม่สำเร็จ แต่จะบันทึกข้อมูลอื่นต่อไป',
                                    isSuccess: false,
                                  );
                                }
                              }
                            }

                            final newAsset = {
                              'asset_id': idController.text,
                              'type': selectedType,
                              'status': selectedStatus,
                              'location_id': widget.locationId,
                              'brand_model': brandController.text, // Add brand
                              // ใช้ชื่อ user ที่ Login อยู่ ถ้าไม่มีให้ใช้ 'Admin'
                              'inspectorName':
                                  ApiService().currentUser?['fullname'] ??
                                  'Admin',
                              'image_url': imageUrl,
                              'images': [],
                            };

                            final result = await ApiService().addAsset(
                              newAsset,
                            );

                            if (result['success']) {
                              await _loadData();
                              if (context.mounted) {
                                Navigator.pop(context);
                                _showCustomSnackBar(
                                  'เพิ่ม ${idController.text} สำเร็จ',
                                  isSuccess: true,
                                );
                              }
                            } else {
                              setDialogState(() => isSaving = false);
                              if (mounted) {
                                _showCustomSnackBar(
                                  result['message'],
                                  isSuccess: false,
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'เพิ่ม',
                          style: TextStyle(color: Colors.white),
                        ),
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
    final TextEditingController idController = TextEditingController(
      text: equipment['asset_id'] ?? '',
    );
    final TextEditingController brandController = TextEditingController(
      text: equipment['brand_model'] ?? '',
    );
    String selectedType = equipment['type'] as String;
    String selectedStatus = equipment['status'] ?? 'ปกติ';

    // Image Editing State
    File? selectedImage;
    String? currentImageUrl = equipment['image_url'];
    final ImagePicker picker = ImagePicker();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.edit, color: Color(0xFF5593E4), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'แก้ไขครุภัณฑ์',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // ⭐ แก้: ใช้ stretch แทน start
                  children: [
                    TextField(
                      controller: idController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'รหัสครุภัณฑ์ (Asset ID)',
                        prefixIcon: const Icon(
                          Icons.qr_code,
                          color: Color(0xFF5593E4),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: brandController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'ยี่ห้อ/รุ่น (Brand/Model)',
                        prefixIcon: const Icon(
                          Icons.branding_watermark,
                          color: Color(0xFF5593E4),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'ประเภท',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
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
                                Text(
                                  type['name'] as String,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() => selectedType = value!);
                              },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'สถานะ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusList.map((status) {
                        final isSelected = selectedStatus == status['name'];
                        return InkWell(
                          onTap: isSaving
                              ? null
                              : () {
                                  setDialogState(
                                    () => selectedStatus =
                                        status['name'] as String,
                                  );
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (status['color'] as Color).withValues(
                                      alpha: 0.2,
                                    )
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? status['color'] as Color
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  status['icon'] as IconData,
                                  size: 18,
                                  color: status['color'] as Color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  status['name'] as String,
                                  style: TextStyle(
                                    color: status['color'] as Color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'รูปภาพ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: isSaving
                          ? null
                          : () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt),
                                        title: const Text('ถ่ายรูป'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final XFile? photo = await picker
                                              .pickImage(
                                                source: ImageSource.camera,
                                              );
                                          if (photo != null) {
                                            setDialogState(
                                              () => selectedImage = File(
                                                photo.path,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo_library,
                                          color: Color(0xFF99CD60),
                                        ),
                                        title: const Text('เลือกจาก Gallery'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final XFile? image = await picker
                                              .pickImage(
                                                source: ImageSource.gallery,
                                              );
                                          if (image != null) {
                                            setDialogState(
                                              () => selectedImage = File(
                                                image.path,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                      child: Container(
                        height: 150,
                        // ลบ width: double.infinity ออก เพราะใช้ stretch แล้ว
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                    // ปุ่มลบรูป (มุมขวาบน)
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedImage = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : (currentImageUrl != null &&
                                  currentImageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      currentImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                    ),
                                    // ปุ่มลบรูป (มุมขวาบน)
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            currentImageUrl = null; // ลบรูปออก
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'เพิ่มรูปภาพ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (idController.text.isNotEmpty) {
                            setDialogState(() => isSaving = true);

                            // Prepare FULL Data Object for API
                            final updatedData = Map<String, dynamic>.from(
                              equipment,
                            );
                            updatedData['asset_id'] = idController.text;
                            updatedData['brand_model'] =
                                brandController.text; // Add brand
                            updatedData['type'] = selectedType;
                            updatedData['status'] = selectedStatus;
                            // Ensure required fields exist
                            updatedData['brand_model'] ??= '';
                            updatedData['brand_model'] ??= '';
                            updatedData['location_id'] = widget.locationId;

                            // Handle Image Upload & Deletion
                            if (selectedImage != null) {
                              // ผู้ใช้เลือกรูปใหม่ -> อัปโหลด
                              setDialogState(() => isSaving = true);
                              final uploadedUrl = await ApiService()
                                  .uploadImage(selectedImage!);
                              if (uploadedUrl != null) {
                                updatedData['image_url'] = uploadedUrl;
                                updatedData['images'] = [
                                  uploadedUrl,
                                ]; // ⭐ อัปเดต List ด้วย
                              }
                            } else if (currentImageUrl == null) {
                              // ผู้ใช้ลบรูปออก -> ส่ง empty string และ empty list
                              updatedData['image_url'] = '';
                              updatedData['images'] =
                                  []; // ⭐ ต้องลบ List ออกด้วยไม่งั้น API Service จะไปหยิบอันเก่า
                            } else {
                              // ไม่ได้แก้ไขรูป -> ใช้ URL เดิม
                              updatedData['image_url'] = currentImageUrl;
                              // images ปล่อยไว้เหมือนเดิม (หรือจะ update ให้ตรงกันก็ได้ แต่ไม่ซีเรียสเท่าการลบ)
                            }

                            // Update inspector to current user
                            updatedData['inspectorName'] =
                                ApiService().currentUser?['fullname'] ??
                                'Admin';

                            final result = await ApiService().updateAsset(
                              equipment['asset_id'].toString(),
                              updatedData,
                            );

                            if (result['success']) {
                              await _loadData();
                              if (context.mounted) {
                                Navigator.pop(context);
                                _showCustomSnackBar(
                                  'บันทึกสำเร็จ',
                                  isSuccess: true,
                                );
                              }
                            } else {
                              setDialogState(() => isSaving = false);
                              if (mounted) {
                                _showCustomSnackBar(
                                  result['message'],
                                  isSuccess: false,
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5593E4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'บันทึก',
                          style: TextStyle(color: Colors.white),
                        ),
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
    bool isDeleting = false;
    // id parameter here is actually asset_id or id string, but for API we need ROW ID.
    // So we should find the item again using index to be sure, or better pass the whole object.
    final equipment = equipmentList[index];
    final assetIdVal = equipment['asset_id']
        .toString(); // Use asset_id (String) for deletion

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text('ยืนยันการลบ', style: TextStyle(fontSize: 20)),
                ],
              ),
              content: Text(
                'คุณต้องการลบ "$assetIdVal"\nใช่หรือไม่?\n\nการลบจะไม่สามารถกู้คืนได้',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          final result = await ApiService().deleteAsset(
                            assetIdVal,
                          );

                          if (result['success']) {
                            await _loadData();
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showCustomSnackBar('ลบสำเร็จ', isSuccess: true);
                            }
                          } else {
                            setDialogState(() => isDeleting = false);
                            if (mounted) {
                              _showCustomSnackBar(
                                result['message'],
                                isSuccess: false,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('ลบ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'ไม่มีครุภัณฑ์ในห้องนี้',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            equipmentList.isEmpty
                ? 'กดปุ่ม + ด้านล่างเพื่อเพิ่ม'
                : 'ไม่พบข้อมูลตาม Filter',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // Custom SnackBar Helper
  void _showCustomSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSuccess ? 'สำเร็จ' : 'แจ้งเตือน',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF99CD60)
            : const Color(0xFFE44F5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
