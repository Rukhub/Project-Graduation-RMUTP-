import 'package:flutter/material.dart';
import 'api_service.dart';
import 'equipment_detail_screen.dart';

class AdminActivityHistoryScreen extends StatefulWidget {
  const AdminActivityHistoryScreen({super.key});

  @override
  State<AdminActivityHistoryScreen> createState() =>
      _AdminActivityHistoryScreenState();
}

class _AdminActivityHistoryScreenState extends State<AdminActivityHistoryScreen>
    with SingleTickerProviderStateMixin {
  // ⭐ Add Mixin

  List<Map<String, dynamic>> allActivities =
      []; // Rename from checkLogs to avoid confusion
  bool isLoading = true;
  String? errorMessage;
  late TabController _tabController; // ⭐ TabController

  // สถิติ
  int totalInspections = 0;
  int normalCount = 0;
  int repairingCount = 0;
  int brokenCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // ⭐ Init TabController length 3
    _loadActivityHistory();
  }

  @override
  void dispose() {
    _tabController.dispose(); // ⭐ Dispose
    super.dispose();
  }

  Future<void> _loadActivityHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUser = ApiService().currentUser;
      final checkerName =
          currentUser?['fullname'] ?? currentUser?['username'] ?? 'Unknown';

      debugPrint('👤 Loading history for: $checkerName'); // ⭐ Debug 1

      // 1. ดึงประวัติการตรวจสอบ
      final logs = await ApiService().getCheckLogsByChecker(checkerName);
      debugPrint('📋 Logs found: ${logs.length}'); // ⭐ Debug 2

      // 2. ดึงประวัติการแจ้งปัญหา (ทั้งหมด - ไม่ใช่แค่ของ Admin)
      final reports = await ApiService().getReports(); // ✅ ใช้ getReports() แทน
      debugPrint('📢 Reports found: ${reports.length}'); // ⭐ Debug 3

      // 3. แปลงข้อมูล
      final processedLogs = logs
          .map(
            (log) => {
              ...log,
              'activity_type': 'inspection',
              'date': log['check_date'],
              'status':
                  log['result_status'] ??
                  log['status'] ??
                  'ไม่ระบุ', // ⭐ Fix: Map result_status
              'note': log['remark'] ?? log['check_detail'], // ⭐ Fix: Map remark
            },
          )
          .toList();

      final processedReports = reports
          .map(
            (report) => {
              ...report,
              'activity_type': 'report',
              'date': report['report_date'],
              'status': report['status'] ?? 'ชำรุด',
              'note': report['issue_detail'],
            },
          )
          .toList();

      // รวมกัน
      List<Map<String, dynamic>> combined = [
        ...processedLogs,
        ...processedReports,
      ];
      debugPrint(
        '🔁 Total combined activities: ${combined.length}',
      ); // ⭐ Debug 4

      // ⭐ DEBUG: Check keys in first item
      if (combined.isNotEmpty) {
        debugPrint('🔍 First Item Keys: ${combined.first.keys.toList()}');
        debugPrint('🔍 First Item Data: ${combined.first}');
      }

      // เรียงลำดับ
      combined.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final dateB =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      // คำนวณสถิติ
      int normal = 0;
      int repairing = 0;
      int broken = 0;

      for (var item in combined) {
        final status = item['status']?.toString() ?? '';
        if (status == 'ปกติ' || status == 'Normal')
          normal++;
        else if (status == 'อยู่ระหว่างซ่อม' || status == 'Repairing')
          repairing++;
        else if (status == 'ชำรุด' || status == 'Broken')
          broken++;
      }

      if (mounted) {
        setState(() {
          allActivities = combined;
          totalInspections = combined.length;
          normalCount = normal;
          repairingCount = repairing;
          brokenCount = broken;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $e';
        });
      }
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '-';
    try {
      final date = DateTime.parse(dateValue.toString());
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return dateValue.toString();
    }
  }

  Map<String, dynamic> _getStatusInfo(String? status) {
    if (status == null || status.isEmpty || status == 'null') {
      return {
        'label': 'ไม่ระบุสถานะ',
        'color': Colors.grey,
        'icon': Icons.help_outline,
        'bgColor': Colors.grey.shade100,
      };
    }
    switch (status) {
      case 'ปกติ':
      case 'Normal':
        return {
          'label': 'ปกติ',
          'color': Color(0xFF4CAF50),
          'icon': Icons.check_circle,
          'bgColor': Color(0xFFE8F5E9),
        };
      case 'อยู่ระหว่างซ่อม':
      case 'Repairing':
        return {
          'label': 'อยู่ระหว่างซ่อม',
          'color': Color(0xFFFF9800),
          'icon': Icons.build_circle,
          'bgColor': Color(0xFFFFF3E0),
        };
      case 'ชำรุด':
      case 'Broken':
        return {
          'label': 'ชำรุด',
          'color': Color(0xFFF44336),
          'icon': Icons.error,
          'bgColor': Color(0xFFFFEBEE),
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info_outline,
          'bgColor': Colors.grey.shade100,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF9A2C2C)),
            )
          : errorMessage != null
          ? _buildErrorState()
          : allActivities.isEmpty
          ? _buildEmptyState()
          : Column(
              // ⭐ Structure Change
              children: [
                _buildSummarySection(), // Keep summary on top
                Expanded(
                  child: TabBarView(
                    // ⭐ TabBarView
                    controller: _tabController,
                    children: [
                      // Tab 1: แจ้งซ่อม (Broken)
                      _buildActivityList((item) {
                        final status = item['status']?.toString() ?? '';
                        return status == 'ชำรุด' ||
                            status == 'Broken' ||
                            item['activity_type'] == 'report';
                      }, 'รายการแจ้งซ่อม'),

                      // Tab 2: อยู่ระหว่างซ่อม (Repairing)
                      _buildActivityList((item) {
                        final status = item['status']?.toString() ?? '';
                        return status == 'อยู่ระหว่างซ่อม' ||
                            status == 'Repairing';
                      }, 'รายการซ่อมบำรุง'),

                      // Tab 3: เสร็จสิ้น/ปกติ (Completed)
                      _buildActivityList((item) {
                        final status = item['status']?.toString() ?? '';
                        return status == 'ปกติ' || status == 'Normal';
                      }, 'ประวัติการตรวจสอบ'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(
        0xFF9A2C2C,
      ), // ⭐ Solid Brand Color (No Gradient)
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'ประวัติการดำเนินการ',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 4, // Thicker indicator
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ), // Reduce size for 3 tabs
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'แจ้งซ่อม'),
          Tab(text: 'กำลังซ่อม'), // Repairing
          Tab(text: 'ตรวจสอบแล้ว'), // Completed/Normal
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF9A2C2C), // Continuous Red Background
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ), // Curved bottom
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              'ทั้งหมด',
              totalInspections,
              Colors.blue.shade700,
            ),
            _buildContainerSummaryItem('ปกติ', normalCount, Colors.green),
            _buildContainerSummaryItem('ซ่อม', repairingCount, Colors.orange),
            _buildContainerSummaryItem('ชำรุด', brokenCount, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ... _buildSummaryItem can remain or use the new one ...
  Widget _buildActivityList(
    bool Function(Map<String, dynamic>) filter,
    String emptyTitle,
  ) {
    // Filter data using the passed function
    final list = allActivities.where(filter).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              'ไม่มีข้อมูล$emptyTitle',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF9A2C2C),
      onRefresh: _loadActivityHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildTimelineCard(list[index]),
      ),
    );
  }

  // Helper for Summary Items
  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ...

  Widget _buildTimelineCard(Map<String, dynamic> item) {
    final activityType = item['activity_type'] ?? 'inspection';
    final isReport = activityType == 'report';
    final status = item['status']?.toString() ?? 'ไม่ระบุ';
    final statusInfo = _getStatusInfo(status);

    final assetId = item['asset_id']?.toString() ?? '-';
    final title =
        item['brand_model'] ?? item['asset_type'] ?? item['type'] ?? assetId;
    // ⭐ Prioritize Room Name
    final roomName = item['room_name'] ?? '';
    final floor = item['floor']?.toString() ?? '';
    String locationText = roomName.isNotEmpty
        ? '$roomName ${floor.isNotEmpty ? "($floor)" : ""}'
        : (item['location'] ?? 'ไม่ระบุสถานที่');

    // Subtitle now shows Room Name prominently if available, else Type/ID
    final subTitle = locationText != 'ไม่ระบุสถานที่'
        ? locationText
        : (item['asset_type'] ?? 'ครุภัณฑ์');

    // Bottom location text can now be used for Asset ID or other info since Room is moved up
    final bottomInfoText = 'รหัส: $assetId';

    final date = _formatDate(item['date']);
    final note = isReport
        ? (item['issue_detail'] ?? item['note']?.toString())
        : (item['remark'] ?? item['check_detail'] ?? item['note']?.toString());

    // ⭐ Actor Name (Verified By / Reported By)
    final actorName = isReport
        ? (item['reporter_name'] ?? 'ไม่ระบุผู้แจ้ง')
        : (item['checker_name'] ?? item['inspectorName'] ?? 'ไม่ระบุผู้ตรวจ');

    // ⭐ Image Logic
    String? imageUrl;
    if (item['images'] != null && (item['images'] as String).isNotEmpty) {
      imageUrl = (item['images'] as String).split(',').first;
    } else if (item['image_url'] != null &&
        (item['image_url'] as String).isNotEmpty) {
      imageUrl = (item['image_url'] as String).split(',').first;
    } else if (item['report_image'] != null &&
        (item['report_image'] as String).isNotEmpty) {
      imageUrl = (item['report_image'] as String).split(',').first;
    }

    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl =
          '${ApiService.baseUrl.replaceAll('/api', '')}/uploads/$imageUrl';
    }

    // ⭐ กำหนดสีตามสถานะ (สำหรับ Border และ Background)
    Color cardBorderColor;
    Color cardBgColor;
    if (isReport ||
        status == 'ชำรุด' ||
        status == 'Broken' ||
        status == 'รอดำเนินการ') {
      cardBorderColor = Colors.red.shade400;
      cardBgColor = Colors.red.shade50;
    } else if (status == 'อยู่ระหว่างซ่อม' ||
        status == 'Repairing' ||
        status == 'กำลังดำเนินการ') {
      cardBorderColor = Colors.orange.shade400;
      cardBgColor = Colors.orange.shade50;
    } else if (status == 'ปกติ' ||
        status == 'Normal' ||
        status == 'ซ่อมเสร็จแล้ว') {
      cardBorderColor = Colors.green.shade400;
      cardBgColor = Colors.green.shade50;
    } else {
      cardBorderColor = Colors.grey.shade300;
      cardBgColor = Colors.grey.shade50;
    }

    return GestureDetector(
      onTap: () {
        if (item['asset_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EquipmentDetailScreen(
                equipment: {
                  'asset_id': assetId,
                  'type': item['asset_type'] ?? item['type'],
                  'status': status,
                  'room_name': roomName,
                  'floor': floor,
                  'location_id': item['location_id'] ?? 0,
                  'image_url': imageUrl,
                  'created_by_name': item['created_by_name'],
                  'reporter_name': item['reporter_name'],
                  'report_reason': item['issue_detail'] ?? item['note'],
                  'brand_model': item['brand_model'],
                },
                roomName: roomName.isNotEmpty
                    ? (floor.isNotEmpty
                          ? '$roomName (${floor.startsWith('ชั้น') ? floor : 'ชั้น $floor'})'
                          : roomName)
                    : 'ไม่ระบุห้อง',
                autoOpenCheckDialog: false,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cardBorderColor.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: cardBorderColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: cardBorderColor,
                  width: 5,
                ), // ⭐ แถบสีซ้าย
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Header with status color hint
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isReport
                              ? Icons.warning_amber_rounded
                              : statusInfo['icon'],
                          size: 16,
                          color: cardBorderColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isReport ? 'แจ้งซ่อม' : statusInfo['label'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cardBorderColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Top Row: Image + Text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: cardBorderColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          image: (imageUrl != null && imageUrl.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (imageUrl == null || imageUrl.isEmpty)
                            ? Icon(
                                isReport
                                    ? Icons.broken_image_rounded
                                    : Icons.inventory_2_rounded,
                                color: cardBorderColor.withValues(alpha: 0.5),
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),

                      // Text Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  date.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              subTitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade300,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 12,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    bottomInfoText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bottom Row: Status + Actor/Note
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isReport
                                ? const Color(0xFFFEF2F2)
                                : statusInfo['bgColor'],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isReport
                                    ? Icons.warning_amber_rounded
                                    : statusInfo['icon'],
                                size: 12,
                                color: isReport
                                    ? Colors.red
                                    : statusInfo['color'],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isReport ? 'แจ้งซ่อม' : statusInfo['label'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isReport
                                      ? Colors.red
                                      : statusInfo['color'],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Actor Name
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              actorName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                            ),
                            // If note exists, show small indicator
                            if (note != null &&
                                note.isNotEmpty &&
                                note != 'null') ...[
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                width: 1,
                                height: 12,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.comment_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(errorMessage ?? 'Error'));
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('ไม่มีประวัติการดำเนินการ'));
  }
}
