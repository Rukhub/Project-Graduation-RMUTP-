import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'equipment_detail_screen.dart';
import 'report_problem_screen.dart';

import 'api_service.dart'; // import api_service
import 'app_drawer.dart';
import 'services/firebase_service.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class KrupanRoomScreen extends StatefulWidget {
  final String roomName;
  final int floor;
  final dynamic locationId; // รับ locationId (int or String)

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
  StreamSubscription? _assetsSubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filter ที่เลือก
  String selectedTypeFilter = 'ทั้งหมด';
  String selectedStatusFilter = 'ทั้งหมด';

  // Selection Mode State
  bool isSelectionMode = false;
  Set<String> selectedAssetIds = {};

  // Search State
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // รายการสถานะ
  List<Map<String, dynamic>> statusList = [
    {'name': 'ปกติ', 'color': Color(0xFF99CD60), 'icon': Icons.check_circle},
    {'name': 'ชำรุด', 'color': Color(0xFFE44F5A), 'icon': Icons.cancel},
    {
      'name': 'อยู่ระหว่างซ่อม',
      'color': Color(0xFFFECC52),
      'icon': Icons.build_circle,
    },
    {'name': 'ซ่อมไม่ได้', 'color': Color(0xFF6B7280), 'icon': Icons.block},
  ];

  @override
  void initState() {
    super.initState();
    FirebaseService()
        .initializeDefaultCategories(); // Initialize 6 default categories
    _loadData();
  }

  @override
  void dispose() {
    _assetsSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    _assetsSubscription?.cancel();

    _assetsSubscription = FirebaseService()
        .getAssetsByLocationStream(widget.locationId)
        .listen(
          (assets) {
            if (mounted) {
              setState(() {
                equipmentList = assets.map((item) {
                  // Map numerical status to string for UI compatibility
                  String statusName = 'ปกติ';
                  if (item.status is int) {
                    if (item.status == 1) {
                      statusName = 'ปกติ';
                    } else if (item.status == 2) {
                      statusName = 'ชำรุด';
                    } else if (item.status == 3) {
                      // รอดำเนินการ (แต่ถ้ามีคนรับงานแล้วให้โชว์ว่าอยู่ระหว่างซ่อม)
                      if (item.repairerId != null &&
                          item.repairerId!.toString().isNotEmpty) {
                        statusName = 'อยู่ระหว่างซ่อม';
                      } else {
                        statusName = 'รอดำเนินการ';
                      }
                    } else if (item.status == 4) {
                      statusName = 'ซ่อมไม่ได้';
                    }
                  } else if (item.status is String) {
                    statusName = item.status;
                  }

                  return {
                    'asset_id': item.assetId,
                    'id':
                        item.assetId, // Ensure 'id' is available for navigation
                    'asset_type': item.assetType,
                    'type': item.assetType,
                    'asset_name': item.assetName,
                    'brand_model': item.brandModel,
                    'price': item.price,
                    'location_id': item.locationId,
                    'status': statusName,
                    'status_raw': item.status, // Keep raw value
                    'repairer_id': item.repairerId, // ⭐ Add for lock check
                    'auditor_name': item.checkerName,
                    'inspectorName': item.checkerName,
                    'images': item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? [item.imageUrl!]
                        : <String>[],
                    'asset_image_url': item.imageUrl,
                    'created_name': item.createdBy,
                    'purchase_at': item.purchaseAt,
                    'created_at': item.createdAt,
                  };
                }).toList();
                isLoading = false;
              });
            }
          },
          onError: (e) {
            debugPrint('🚨 Firebase Load Assets Error: $e');
            if (mounted) setState(() => isLoading = false);
          },
        );
  }

  // กรองครุภัณฑ์ตาม Filter และ Search
  List<Map<String, dynamic>> get filteredEquipmentList {
    return equipmentList.where((item) {
      // Type filter
      bool matchType =
          selectedTypeFilter == 'ทั้งหมด' || item['type'] == selectedTypeFilter;

      // Status filter
      bool matchStatus =
          selectedStatusFilter == 'ทั้งหมด' ||
          item['status'] == selectedStatusFilter;

      // Search filter - ค้นหาจาก ชื่อ, รหัส, หรือประเภท
      bool matchSearch =
          searchQuery.isEmpty ||
          (item['asset_name'] ?? '').toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          (item['asset_id'] ?? '').toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          (item['type'] ?? '').toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          );

      return matchType && matchStatus && matchSearch;
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
          if (isSelectionMode)
            TextButton(
              onPressed: () {
                setState(() {
                  if (selectedAssetIds.length == filteredEquipmentList.length) {
                    selectedAssetIds.clear();
                  } else {
                    selectedAssetIds = filteredEquipmentList
                        .map((e) => (e['asset_id'] ?? e['id']).toString())
                        .toSet();
                  }
                });
              },
              child: Text(
                selectedAssetIds.length == filteredEquipmentList.length
                    ? 'ไม่เลือก'
                    : 'เลือกหมด',
                style: const TextStyle(color: Colors.white),
              ),
            ),

          if (!isSelectionMode && ApiService().currentUser?['role'] == 'admin')
            IconButton(
              icon: const Icon(Icons.checklist, color: Colors.white),
              tooltip: 'เลือกรายการ',
              onPressed: () {
                setState(() {
                  isSelectionMode = true;
                  selectedAssetIds.clear();
                });
              },
            ),

          if (!isSelectionMode)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),

          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  isSelectionMode = false;
                  selectedAssetIds.clear();
                });
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

                // Search Bar
                _buildSearchBar(),
                const SizedBox(height: 10),

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
      floatingActionButton: isSelectionMode
          ? SizedBox(
              width: 140,
              height: 56,
              child: FloatingActionButton.extended(
                onPressed: selectedAssetIds.isEmpty ? null : _showMoveDialog,
                backgroundColor: selectedAssetIds.isEmpty
                    ? Colors.grey
                    : const Color(0xFF9A2C2C),
                icon: const Icon(Icons.drive_file_move, color: Colors.white),
                label: Text(
                  'ย้าย (${selectedAssetIds.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : ApiService().currentUser?['role'] == 'admin'
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

  // Search Bar Widget
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey.shade500, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'ค้นหาครุภัณฑ์ (ชื่อ, รหัส, ประเภท)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  searchController.clear();
                  searchQuery = '';
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade700),
              ),
            ),
        ],
      ),
    );
  }

  // Filter Section - Chip Based (แสดงชื่อเต็ม)
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Filter
          Text(
            'ประเภท',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseService().getAssetCategoriesStream(),
            builder: (context, snapshot) {
              List<String> categories = ['ทั้งหมด'];
              if (snapshot.hasData) {
                categories.addAll(
                  snapshot.data!.map((e) => e['name'] as String),
                );
              }

              // Ensure selected value is still valid
              if (!categories.contains(selectedTypeFilter)) {
                selectedTypeFilter = 'ทั้งหมด';
              }

              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = selectedTypeFilter == cat;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => selectedTypeFilter = cat);
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: const Color(0xFF9A2C2C),
                        checkmarkColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF9A2C2C)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Status Filter
          Text(
            'สถานะ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // "ทั้งหมด" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      'ทั้งหมด',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selectedStatusFilter == 'ทั้งหมด'
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selectedStatusFilter == 'ทั้งหมด'
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                    selected: selectedStatusFilter == 'ทั้งหมด',
                    onSelected: (selected) {
                      setState(() => selectedStatusFilter = 'ทั้งหมด');
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: const Color(0xFF9A2C2C),
                    checkmarkColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selectedStatusFilter == 'ทั้งหมด'
                            ? const Color(0xFF9A2C2C)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // Status chips from statusList
                ...statusList.map((status) {
                  final statusName = status['name'] as String;
                  final isSelected = selectedStatusFilter == statusName;
                  final statusColor = status['color'] as Color;
                  final statusIcon = status['icon'] as IconData;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        statusIcon,
                        size: 16,
                        color: isSelected ? Colors.white : statusColor,
                      ),
                      label: Text(
                        statusName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => selectedStatusFilter = statusName);
                      },
                      backgroundColor: Colors.grey.shade100,
                      selectedColor: statusColor,
                      checkmarkColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? statusColor
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                  );
                }),
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
    // Use dynamic icon logic
    IconData equipmentIcon = Icons.category_outlined;
    Color equipmentColor = const Color(0xFF9A2C2C);

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
          if (isSelectionMode) {
            final id = (equipment['asset_id'] ?? equipment['id']).toString();
            setState(() {
              if (selectedAssetIds.contains(id)) {
                selectedAssetIds.remove(id);
              } else {
                selectedAssetIds.add(id);
              }
            });
            return;
          }
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
              // Checkbox for Selection Mode
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    selectedAssetIds.contains(
                          (equipment['asset_id'] ?? equipment['id']).toString(),
                        )
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: const Color(0xFF9A2C2C),
                  ),
                ),

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
                    // Asset ID
                    Text(
                      (equipment['asset_id'] ??
                              equipment['id'] ??
                              'ไม่ระบุรหัส')
                          .toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Asset Name - แสดงได้ 2 บรรทัด
                    if (equipment['asset_name'] != null &&
                        equipment['asset_name'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          equipment['asset_name'].toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // Type
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (equipment['type'] ?? '-').toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Status Badge
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
                    // Verify Button with Lock Check
                    Builder(
                      builder: (context) {
                        final currentUid =
                            FirebaseAuth.instance.currentUser?.uid;
                        final repairerId = equipment['repairer_id'];
                        final equipmentStatus = (equipment['status'] ?? 'ปกติ')
                            .toString();
                        final inspectorName = equipment['inspectorName'] ??
                            equipment['auditor_name'] ??
                            '';

                        // Check Lock (Same logic as detail screen)
                        bool isLocked = false;

                        // 1. Check by ID (Primary)
                        if (equipmentStatus == 'อยู่ระหว่างซ่อม' &&
                            repairerId != null &&
                            repairerId != currentUid) {
                          isLocked = true;
                        }
                        // 2. Check by Name (Fallback for legacy data)
                        else if (equipmentStatus == 'อยู่ระหว่างซ่อม' &&
                            repairerId == null &&
                            inspectorName != null) {
                          final currentName =
                              ApiService().currentUser?['fullname'];
                          if (inspectorName != currentName) {
                            isLocked = true;
                          }
                        }

                        return _buildCompactAssetButton(
                          icon: Icons.verified_outlined,
                          color: isLocked ? Colors.grey : Colors.green,
                          tooltip: isLocked ? 'ถูกล็อคโดยผู้อื่น' : 'ตรวจสอบ',
                          onPressed: isLocked
                              ? null
                              : () => _navigateToInspect(index, equipment),
                        );
                      },
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
    required VoidCallback? onPressed, // Make nullable
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
    // Check if equipment is locked by another repairer
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final repairerId = equipment['repairer_id'];
    final equipmentStatus = (equipment['status'] ?? 'ปกติ').toString();
    final inspectorName = equipment['inspectorName'] ??
        equipment['auditor_name'] ??
        '';

    // Check Lock
    bool isLocked = false;
    String? lockedByName;

    // 1. Check by ID (Primary)
    if (equipmentStatus == 'อยู่ระหว่างซ่อม' &&
        repairerId != null &&
        repairerId != currentUid) {
      isLocked = true;
      lockedByName = inspectorName ?? 'ผู้ใช้อื่น';
    }
    // 2. Check by Name (Fallback for legacy data)
    else if (equipmentStatus == 'อยู่ระหว่างซ่อม' &&
        repairerId == null &&
        inspectorName != null) {
      final currentName = ApiService().currentUser?['fullname'];
      if (inspectorName != currentName) {
        isLocked = true;
        lockedByName = inspectorName;
      }
    }

    // If locked, show alert and return
    if (isLocked) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.lock, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('ไม่สามารถดำเนินการได้'),
            ],
          ),
          content: Text(
            'ครุภัณฑ์นี้กำลังอยู่ระหว่างซ่อมโดย "$lockedByName"\n\nคุณไม่สามารถตรวจสอบหรือบันทึกผลการซ่อมได้',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'รับทราบ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Otherwise, proceed to detail screen
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => EquipmentDetailScreen(
          equipment: equipment,
          roomName: widget.roomName,
          autoOpenCheckDialog: true,
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
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FirebaseService().getAssetCategoriesStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final categories = snapshot.data!;

                          if (categories.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text('ยังไม่มีหมวดหมู่'),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.folder,
                                    color: Color(0xFF9A2C2C),
                                  ),
                                  title: Text(cat['name'] as String),
                                  subtitle: Text('Order: ${cat['order']}'),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final String? docId = cat['id'];
                                      if (docId != null) {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('ยืนยันระบบลบ'),
                                            content: Text(
                                              'ต้องการลบหมวดหมู่ "${cat['name']}" ใช่หรือไม่?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('ยกเลิก'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'ลบ',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await FirebaseService()
                                              .deleteAssetCategory(docId);
                                          if (context.mounted) {
                                            _showCustomSnackBar(
                                              'ลบหมวดหมู่ "${cat['name']}" สำเร็จ',
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddCategoryDialog(context);
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'เพิ่มหมวดหมู่ใหม่',
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

  // Dialog เพิ่มครุภัณฑ์
  void _showAddEquipmentDialog() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController purchaseAtController = TextEditingController();

    String? selectedCategory;
    File? selectedImage;
    bool isSaving = false;
    final ImagePicker picker = ImagePicker();
    DateTime? purchaseAt;

    String formatThaiPurchaseDate(DateTime d) {
      const months = [
        'มกราคม',
        'กุมภาพันธ์',
        'มีนาคม',
        'เมษายน',
        'พฤษภาคม',
        'มิถุนายน',
        'กรกฎาคม',
        'สิงหาคม',
        'กันยายน',
        'ตุลาคม',
        'พฤศจิกายน',
        'ธันวาคม',
      ];
      final monthName = months[d.month - 1];
      final buddhistYear = d.year + 543;
      return 'วันที่ ${d.day} เดือน$monthName พ.ศ.$buddhistYear';
    }

    double? parsePriceToDouble(String raw) {
      final cleaned = raw.trim().replaceAll(' ', '');
      if (cleaned.isEmpty) return null;

      // Support:
      // - "1,000.34" (grouping comma + dot decimal)
      // - "2000,34" (comma decimal)
      // - "1000000" (no separators)
      final hasDot = cleaned.contains('.');
      final commaCount = ','.allMatches(cleaned).length;

      String normalized = cleaned;
      if (hasDot) {
        normalized = normalized.replaceAll(',', '');
      } else if (commaCount == 1) {
        final parts = normalized.split(',');
        final dec = parts.length == 2 ? parts[1] : '';
        if (dec.length <= 2) {
          normalized = '${parts[0]}.$dec';
        } else {
          normalized = normalized.replaceAll(',', '');
        }
      } else {
        normalized = normalized.replaceAll(',', '');
      }

      return double.tryParse(normalized);
    }

    String _formatThousands(String digits) {
      final d = digits.replaceAll(RegExp(r'[^0-9]'), '');
      if (d.isEmpty) return '';
      final buf = StringBuffer();
      for (int i = 0; i < d.length; i++) {
        final left = d.length - i;
        buf.write(d[i]);
        if (left > 1 && left % 3 == 1) {
          buf.write(',');
        }
      }
      return buf.toString();
    }

    TextEditingValue _formatPriceValue(
      TextEditingValue oldValue,
      TextEditingValue newValue,
    ) {
      final raw = newValue.text;
      if (raw.isEmpty) return newValue;

      final filtered = raw.replaceAll(RegExp(r'[^0-9\.,]'), '');
      final hasDot = filtered.contains('.');

      String integerPart = filtered;
      String? decimalPart;

      if (hasDot) {
        final parts = filtered.split('.');
        integerPart = parts.first;
        decimalPart = parts.length > 1 ? parts.sublist(1).join('') : '';
      } else {
        final commaCount = ','.allMatches(filtered).length;
        if (commaCount == 1) {
          final parts = filtered.split(',');
          final dec = parts.length == 2 ? parts[1] : '';
          if (dec.length <= 2) {
            integerPart = parts.first;
            decimalPart = dec;
          } else {
            integerPart = filtered;
          }
        } else {
          integerPart = filtered;
        }
      }

      integerPart = integerPart.replaceAll(',', '');
      final formattedInt = _formatThousands(integerPart);
      final formatted = decimalPart == null
          ? formattedInt
          : '$formattedInt.${decimalPart.substring(0, decimalPart.length.clamp(0, 2))}';

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final priceFormatter = TextInputFormatter.withFunction(_formatPriceValue);

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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Asset ID
                    TextField(
                      controller: idController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'รหัสครุภัณฑ์ (Asset ID)',
                        hintText: 'เช่น 1-1-4052-2506',
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

                    // Asset Name
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'ชื่อครุภัณฑ์ (Asset Name)',
                        hintText: 'เช่น คอมพิวเตอร์ All-in-One',
                        prefixIcon: const Icon(
                          Icons.label_important,
                          color: Color(0xFF9A2C2C),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Category Dropdown (from Firestore)
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FirebaseService().getAssetCategoriesStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final categories = snapshot.data!;

                        // Set default if not set
                        if (selectedCategory == null && categories.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setDialogState(() {
                              selectedCategory = categories.first['name'];
                            });
                          });
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'หมวดหมู่',
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: DropdownButton<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                underline: const SizedBox(),
                                hint: const Text('เลือกหมวดหมู่'),
                                items: [
                                  ...categories.map(
                                    (cat) => DropdownMenuItem(
                                      value: cat['name'] as String,
                                      child: Text(cat['name'] as String),
                                    ),
                                  ),
                                  // Admin can add new category
                                  if (ApiService().currentUser?['role'] ==
                                      'admin')
                                    const DropdownMenuItem(
                                      value: '__ADD_NEW__',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.add,
                                            color: Color(0xFF9A2C2C),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '+ เพิ่มหมวดหมู่ใหม่',
                                            style: TextStyle(
                                              color: Color(0xFF9A2C2C),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                                onChanged: isSaving
                                    ? null
                                    : (value) {
                                        if (value == '__ADD_NEW__') {
                                          _showAddCategoryDialog(context);
                                        } else {
                                          setDialogState(
                                            () => selectedCategory = value,
                                          );
                                        }
                                      },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: purchaseAtController,
                      readOnly: true,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'วันที่ซื้อ (Purchase Date)',
                        hintText: 'เลือกวันที่ซื้อ',
                        prefixIcon: const Icon(
                          Icons.calendar_month,
                          color: Color(0xFF9A2C2C),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onTap: isSaving
                          ? null
                          : () async {
                              final now = DateTime.now();
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: purchaseAt ?? now,
                                firstDate: DateTime(1980),
                                lastDate: DateTime(now.year + 1),
                              );
                              if (selected == null) return;
                              setDialogState(() {
                                purchaseAt = selected;
                                purchaseAtController.text =
                                    formatThaiPurchaseDate(selected);
                              });
                            },
                    ),
                    const SizedBox(height: 18),

                    // Price
                    TextField(
                      controller: priceController,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                        priceFormatter,
                      ],
                      decoration: InputDecoration(
                        labelText: 'ราคา (Price)',
                        hintText: 'เช่น 20,000.00',
                        prefixIcon: const Icon(
                          Icons.payments,
                          color: Color(0xFF9A2C2C),
                        ),
                        suffixText: 'บาท',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Image Picker
                    Column(
                      children: [
                        const Center(
                          child: Text(
                            'รูปภาพ (ไม่บังคับ)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (selectedImage != null)
                          Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      selectedImage!,
                                      height: 140,
                                      width: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(
                                      () => selectedImage = null,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildImageSourceButton(
                                icon: Icons.camera_alt_rounded,
                                label: 'ถ่ายรูป',
                                color: const Color(0xFF5593E4),
                                onTap: () async {
                                  final XFile? photo = await picker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 80,
                                  );
                                  if (photo != null) {
                                    setDialogState(() {
                                      selectedImage = File(photo.path);
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 32),
                              _buildImageSourceButton(
                                icon: Icons.photo_library_rounded,
                                label: 'คลังรูป',
                                color: const Color(0xFF99CD60),
                                onTap: () async {
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80,
                                  );
                                  if (image != null) {
                                    setDialogState(() {
                                      selectedImage = File(image.path);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                      ],
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
                  onPressed: (isSaving || selectedCategory == null)
                      ? null
                      : () async {
                          if (idController.text.isEmpty ||
                              nameController.text.isEmpty ||
                              priceController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final rawPrice = priceController.text;
                          final parsedPrice = parsePriceToDouble(rawPrice);
                          debugPrint(
                            '💰 KrupanRoom addAsset price raw="$rawPrice" parsed=$parsedPrice',
                          );
                          if (rawPrice.trim().isNotEmpty && parsedPrice == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'รูปแบบราคาไม่ถูกต้อง (ตัวอย่างที่ถูกต้อง: 20,000.00)',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          final success = await FirebaseService().addAsset(
                            assetId: idController.text,
                            assetName: nameController.text,
                            assetType: selectedCategory!,
                            price: parsedPrice,
                            locationId: widget.locationId,
                            createdId: ApiService().currentUser?['uid']?.toString(),
                            createdBy: ApiService().currentUser?['fullname'],
                            purchaseAt: purchaseAt,
                            imageFile: selectedImage,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'เพิ่มครุภัณฑ์สำเร็จ'
                                      : 'เพิ่มครุภัณฑ์ไม่สำเร็จ',
                                ),
                                backgroundColor: success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
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

  // Dialog เพิ่มหมวดหมู่ใหม่ (Admin only)
  void _showAddCategoryDialog(BuildContext parentContext) {
    final TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('เพิ่มหมวดหมู่ใหม่'),
          content: TextField(
            controller: categoryController,
            decoration: const InputDecoration(
              labelText: 'ชื่อหมวดหมู่',
              hintText: 'เช่น ครุภัณฑ์โทรคมนาคม',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (categoryController.text.isNotEmpty) {
                  final success = await FirebaseService().addAssetCategory(
                    categoryController.text,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'เพิ่มหมวดหมู่สำเร็จ'
                              : 'เพิ่มหมวดหมู่ไม่สำเร็จ',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('เพิ่ม'),
            ),
          ],
        );
      },
    );
  }

  // Dialog แก้ไขครุภัณฑ์
  void _showEditEquipmentDialog(int index, Map<String, dynamic> equipment) {
    final TextEditingController idController = TextEditingController(
      text: equipment['asset_id'] ?? '',
    );
    // ⭐ เปลี่ยนจาก brandController เป็น nameController
    final TextEditingController nameController = TextEditingController(
      text: equipment['name_asset'] ?? equipment['asset_name'] ?? '',
    );
    String selectedType = equipment['type'] as String;
    String selectedStatus = (equipment['status'] ?? 'ปกติ').toString();

    // Image Editing State
    File? selectedImage;
    String? currentImageUrl = equipment['asset_image_url'];
    final ImagePicker picker = ImagePicker();
    bool isSaving = false;
    

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedStatusMeta = statusList.firstWhere(
              (s) => (s['name']?.toString() ?? '') == selectedStatus,
              orElse: () => statusList.first,
            );

            return SafeArea(
              child: AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
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
                    // ⭐ TextField ชื่อครุภัณฑ์ (Asset Name)
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'ชื่อครุภัณฑ์ (Asset Name)',
                        prefixIcon: const Icon(
                          Icons.label_important_outline,
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
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FirebaseService().getAssetCategoriesStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final categories = snapshot.data!;

                          // Handle if the current selectedType is not in the list (rare but possible)
                          if (categories.isNotEmpty &&
                              !categories.any(
                                (c) => c['name'] == selectedType,
                              )) {
                            // Don't auto-change selectedType here to avoid UI jumps, but ensure items has it or handle gracefully
                          }

                          return DropdownButton<String>(
                            value:
                                categories.any((c) => c['name'] == selectedType)
                                ? selectedType
                                : null,
                            isExpanded: true,
                            underline: const SizedBox(),
                            hint: const Text('เลือกหมวดหมู่'),
                            items: categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat['name'] as String,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.folder_open_outlined,
                                      size: 20,
                                      color: Color(0xFF9A2C2C),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        cat['name'] as String,
                                        style: const TextStyle(fontSize: 16),
                                        overflow: TextOverflow
                                            .ellipsis, // ⭐ Prevent overflow
                                      ),
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
                          );
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (selectedStatusMeta['color'] as Color)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedStatusMeta['color'] as Color,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedStatusMeta['icon'] as IconData,
                            size: 18,
                            color: selectedStatusMeta['color'] as Color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedStatus,
                              style: TextStyle(
                                color: selectedStatusMeta['color'] as Color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                          if (idController.text.isEmpty) return;
                          setDialogState(() => isSaving = true);

                          final updatedData = Map<String, dynamic>.from(
                            equipment,
                          );
                          updatedData['asset_id'] = idController.text;
                          updatedData['name_asset'] = nameController.text;
                          updatedData['asset_name'] = nameController.text;
                          updatedData['type'] = selectedType;
                          updatedData['name_asset'] ??= '';
                          updatedData['location_id'] = widget.locationId;

                          if (selectedImage != null) {
                            final uploadedUrl =
                                await FirebaseService().uploadAssetImage(
                              selectedImage!,
                              idController.text,
                            );
                            if (uploadedUrl != null) {
                              updatedData['asset_image_url'] = uploadedUrl;
                              updatedData['images'] = [uploadedUrl];
                            }
                          } else if (currentImageUrl == null) {
                            updatedData['asset_image_url'] = '';
                            updatedData['images'] = [];
                          } else {
                            updatedData['asset_image_url'] = currentImageUrl;
                          }

                          final currentUid =
                              ApiService().currentUser?['uid']?.toString() ??
                                  'unknown_uid';
                          final currentName =
                              ApiService().currentUser?['fullname']
                                      ?.toString() ??
                                  'Admin';

                          final firestoreUpdate = <String, dynamic>{
                            'asset_id': idController.text,
                            'asset_name': nameController.text,
                            'name_asset': nameController.text,
                            'asset_type': selectedType,
                            'asset_image_url': updatedData['asset_image_url'],
                          };

                          try {
                            await FirebaseService().updateAsset(
                              equipment['asset_id'].toString(),
                              firestoreUpdate,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showCustomSnackBar(
                                'บันทึกสำเร็จ',
                                isSuccess: true,
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              _showCustomSnackBar(
                                'เกิดข้อผิดพลาด: $e',
                                isSuccess: false,
                              );
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
            ),
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
                          try {
                            await FirebaseService().deleteAsset(assetIdVal);
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showCustomSnackBar('ลบสำเร็จ', isSuccess: true);
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (mounted) {
                              _showCustomSnackBar(
                                'เกิดข้อผิดพลาด: $e',
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

  // ✅ NEW: Move Dialog - Select Target Room
  Future<void> _showMoveDialog() async {
    // Fetch all locations via Firestore
    final locationModels = await FirebaseService().getLocations();

    // Convert to map format expected by UI
    final locations = locationModels
        .map(
          (loc) => {
            'location_id': loc.locationId,
            'room_name': loc.roomName,
            'floor': loc.floor,
          },
        )
        .toList();

    if (!mounted) return;

    // Filter out current room
    final otherRooms = locations.where((loc) {
      return loc['location_id']?.toString() != widget.locationId.toString();
    }).toList();

    if (otherRooms.isEmpty) {
      _showCustomSnackBar('ไม่มีห้องอื่นให้ย้าย', isSuccess: false);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        String selectedFloor = '';
        String query = '';

        final floors = otherRooms
            .map((e) => (e['floor'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        floors.sort((a, b) => a.compareTo(b));
        if (floors.isNotEmpty) {
          selectedFloor = floors.first;
        }

        List<Map<String, dynamic>> _filteredRooms(
          List<Map<String, dynamic>> rooms,
          String floor,
          String q,
        ) {
          final floorTrim = floor.trim();
          final qTrim = q.trim().toLowerCase();
          return rooms.where((room) {
            final f = (room['floor'] ?? '').toString().trim();
            if (floorTrim.isNotEmpty && f != floorTrim) return false;
            if (qTrim.isEmpty) return true;
            final rn = (room['room_name'] ?? '').toString().toLowerCase();
            return rn.contains(qTrim);
          }).toList();
        }

        Widget _floorChip(
          StateSetter setSheetState,
          String floor,
        ) {
          final isSelected = selectedFloor == floor;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                'ชั้น $floor',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setSheetState(() {
                  selectedFloor = floor;
                });
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: const Color(0xFF9A2C2C),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color:
                      isSelected ? const Color(0xFF9A2C2C) : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final visibleRooms =
                _filteredRooms(otherRooms, selectedFloor, query);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF9A2C2C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.drive_file_move,
                            color: Color(0xFF9A2C2C),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'เลือกห้องปลายทาง',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'ย้าย ${selectedAssetIds.length} รายการ',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: Colors.grey.shade500, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              onChanged: (v) {
                                setSheetState(() {
                                  query = v;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'ค้นหาห้อง',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (query.trim().isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  query = '';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (floors.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: floors.length,
                        itemBuilder: (context, index) {
                          return _floorChip(setSheetState, floors[index]);
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade200, height: 1),
                  Flexible(
                    child: visibleRooms.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'ไม่พบห้องที่ค้นหา',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: visibleRooms.length,
                            itemBuilder: (context, index) {
                              final room = visibleRooms[index];
                              final roomName = room['room_name'] ?? 'ไม่ระบุ';
                              final floor = room['floor'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _executeMoveAssets(
                                        room['location_id'],
                                        targetRoomName:
                                            (room['room_name'] ?? '').toString(),
                                        targetFloor:
                                            (room['floor'] ?? '').toString(),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF9A2C2C,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.meeting_room,
                                              color: Color(0xFF9A2C2C),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  roomName,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'ชั้น $floor',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey.shade400,
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
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ Execute Move Assets
  Future<void> _executeMoveAssets(
    dynamic targetLocationId, {
    String? targetRoomName,
    String? targetFloor,
  }) async {
    final assetIdsList = selectedAssetIds.toList();

    // 🔍 DEBUG: Print what we're sending
    debugPrint('🚚 === MOVE ASSETS DEBUG ===');
    debugPrint('🚚 Asset IDs to move: $assetIdsList');
    debugPrint('🚚 Target Location ID: $targetLocationId');
    debugPrint('🚚 Current Room ID: ${widget.locationId}');

    try {
      debugPrint('🚚 Moving assets via Firestore...');

      await FirebaseService().moveAssetsToLocation(
        assetIds: assetIdsList,
        targetLocationId: targetLocationId,
      );

      debugPrint('✅ Move successful (Firestore)!');
      final roomLabel = (targetRoomName ?? '').trim();
      final floorLabel = (targetFloor ?? '').trim();
      final dest = roomLabel.isEmpty
          ? 'ย้ายสำเร็จ!'
          : floorLabel.isEmpty
              ? 'ย้ายไป $roomLabel แล้ว'
              : 'ย้ายไป $roomLabel (ชั้น $floorLabel) แล้ว';
      _showCustomSnackBar(dest, isSuccess: true);

      // Exit selection mode and refresh
      setState(() {
        isSelectionMode = false;
        selectedAssetIds.clear();
      });

      debugPrint('🚚 Reloading data...');
      await _loadData();
      debugPrint('🚚 Data reloaded!');
    } catch (e) {
      debugPrint('❌ Exception during move: $e');
      _showCustomSnackBar('เกิดข้อผิดพลาด: $e', isSuccess: false);
    }
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

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
