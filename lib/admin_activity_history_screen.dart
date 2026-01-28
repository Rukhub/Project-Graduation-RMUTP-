import 'package:flutter/material.dart';
import 'api_service.dart';
import 'equipment_detail_screen.dart';

class AdminActivityHistoryScreen extends StatefulWidget {
  const AdminActivityHistoryScreen({super.key});

  @override
  State<AdminActivityHistoryScreen> createState() =>
      _AdminActivityHistoryScreenState();
}

class _AdminActivityHistoryScreenState
    extends State<AdminActivityHistoryScreen> {
  List<Map<String, dynamic>> checkLogs = [];
  bool isLoading = true;
  String? errorMessage;

  // สถิติ
  int totalInspections = 0;
  int normalCount = 0; // ปกติ
  int repairingCount = 0; // อยู่ระหว่างซ่อม
  int brokenCount = 0; // ชำรุด

  // Filter
  String selectedFilter = 'ทั้งหมด';
  final List<String> filterOptions = [
    'ทั้งหมด',
    'ปกติ',
    'อยู่ระหว่างซ่อม',
    'ชำรุด',
  ];

  @override
  void initState() {
    super.initState();
    _loadActivityHistory();
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

      // 1. ดึงประวัติการตรวจสอบ (Check Logs)
      final logs = await ApiService().getCheckLogsByChecker(checkerName);

      // 2. ดึงประวัติการแจ้งปัญหาของตัวเอง (My Reports)
      final reports = await ApiService().getMyReports(checkerName);

      // 3. รวมข้อมูล และแปลงให้เป็น format เดียวกัน
      // Add 'activity_type' to distinguish
      final processedLogs = logs
          .map(
            (log) => {
              ...log,
              'activity_type': 'inspection', // เป็นการตรวจสอบ
              'date': log['check_date'],
            },
          )
          .toList();

      final processedReports = reports
          .map(
            (report) => {
              ...report,
              'activity_type': 'report', // เป็นการแจ้งปัญหา
              'date': report['report_date'],
              'status':
                  report['status'] ??
                  'ชำรุด', // ถ้าไม่มีสถานะ ให้ถือว่าชำรุด (เพราะแจ้งซ่อม)
              'note': report['issue_detail'], // map issue_detail -> note
            },
          )
          .toList();

      // รวมกัน
      List<Map<String, dynamic>> allActivities = [
        ...processedLogs,
        ...processedReports,
      ];

      // เรียงลำดับตามวันที่ (ล่าสุดขึ้นก่อน)
      allActivities.sort((a, b) {
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

      for (var item in allActivities) {
        final status = item['status']?.toString() ?? '';
        if (status == 'ปกติ' || status == 'Normal') {
          normal++;
        } else if (status == 'อยู่ระหว่างซ่อม' || status == 'Repairing') {
          repairing++;
        } else if (status == 'ชำรุด' || status == 'Broken') {
          broken++;
        }
      }

      if (mounted) {
        setState(() {
          checkLogs = allActivities; // ใช้ตัวแปร checkLogs เหมือนเดิมแต่เก็บรวม
          totalInspections = allActivities.length;
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

  List<Map<String, dynamic>> get filteredLogs {
    if (selectedFilter == 'ทั้งหมด') return checkLogs;
    return checkLogs.where((log) => log['status'] == selectedFilter).toList();
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
          'color': const Color(0xFF4CAF50),
          'icon': Icons.check_circle,
          'bgColor': const Color(0xFFE8F5E9),
        };
      case 'อยู่ระหว่างซ่อม':
      case 'Repairing':
        return {
          'label': 'อยู่ระหว่างซ่อม',
          'color': const Color(0xFFFF9800),
          'icon': Icons.build_circle,
          'bgColor': const Color(0xFFFFF3E0),
        };
      case 'ชำรุด':
      case 'Broken':
        return {
          'label': 'ชำรุด',
          'color': const Color(0xFFF44336),
          'icon': Icons.error,
          'bgColor': const Color(0xFFFFEBEE),
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
              child: CircularProgressIndicator(
                // Use Red Theme loading indicator
                color: Color(0xFF9A2C2C),
              ),
            )
          : errorMessage != null
          ? _buildErrorState()
          : checkLogs.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: const Color(0xFF9A2C2C), // Red refresh
              onRefresh: _loadActivityHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummarySection(),
                    const SizedBox(height: 20),
                    _buildFilterSection(),
                    const SizedBox(height: 16),
                    _buildTimelineSection(),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF9A2C2C), // Primary Red
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'ประวัติการดำเนินการ',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            // Red Theme Gradient
            colors: [Color(0xFF9A2C2C), Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9A2C2C), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9A2C2C).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.analytics, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                'สรุปการดำเนินการ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'ตรวจทั้งหมด',
                  totalInspections.toString(),
                  Icons.assignment_turned_in,
                  textColor: const Color(0xFF9A2C2C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'ปกติ',
                  normalCount.toString(),
                  Icons.check_circle,
                  iconColor: const Color(0xFF4CAF50),
                  textColor: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'กำลังซ่อม',
                  repairingCount.toString(),
                  Icons.build_circle,
                  iconColor: const Color(0xFFFF9800),
                  textColor: const Color(0xFFEF6C00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'ชำรุด',
                  brokenCount.toString(),
                  Icons.error,
                  iconColor: const Color(0xFFF44336),
                  textColor: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon, {
    Color? iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Solid White
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? const Color(0xFF9A2C2C), // Default to Theme Red
            size: 28,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600, // Grey Label
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.grey.shade600, size: 22),
          const SizedBox(width: 12),
          Text(
            'กรองตาม:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterOptions.map((filter) {
                  final isSelected = selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF9A2C2C) // Red Active
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF9A2C2C)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final logs = filteredLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.grey.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  'รายการล่าสุด',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF5593E4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${logs.length} รายการ',
                style: const TextStyle(
                  color: Color(0xFF9A2C2C), // Red Text
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildTimelineCard(logs[index]),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> item) {
    final activityType = item['activity_type'] ?? 'inspection';
    final isReport = activityType == 'report';

    final status = item['status']?.toString() ?? 'ไม่ระบุ';
    final statusInfo = _getStatusInfo(status);

    final assetId = item['asset_id']?.toString() ?? '-';
    // Report อาจจะส่ง field ต่างกัน
    final assetType =
        item['asset_type'] ??
        item['type'] ??
        (isReport ? 'แจ้งซ่อม' : 'ครุภัณฑ์');
    final roomName = item['room_name'] ?? '';
    final floor = item['floor']?.toString() ?? '';
    final date = _formatDate(item['date']);
    final note = isReport
        ? (item['issue_detail'] ??
              item['note']?.toString()) // Report ใช้ issue_detail
        : (item['remark'] ?? item['note']?.toString()); // CheckLog ใช้ remark

    return GestureDetector(
      onTap: () {
        // Navigate
        if (item['asset_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EquipmentDetailScreen(
                equipment: {
                  'asset_id': assetId,
                  'type': assetType,
                  'status': status,
                  'room_name': roomName,
                  'floor': floor,
                  'location_id': item['location_id'] ?? 0,
                },
                roomName: roomName.isNotEmpty
                    ? (floor.isNotEmpty
                          ? '$roomName (${floor.startsWith('ชั้น') ? floor : 'ชั้น $floor'})'
                          : roomName)
                    : 'ไม่ระบุห้อง',
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isReport
                    ? Colors.red.shade50
                    : (statusInfo['bgColor'] as Color),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isReport
                            ? Icons.report_problem
                            : (statusInfo['icon'] as IconData),
                        color: isReport
                            ? Colors.red
                            : (statusInfo['color'] as Color),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReport
                            ? 'แจ้งปัญหา'
                            : (statusInfo['label'] as String),
                        style: TextStyle(
                          color: isReport
                              ? Colors.red
                              : (statusInfo['color'] as Color),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    date,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history, // Change icon to history
                      color: Color(0xFF9A2C2C), // Red Icon
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assetId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$assetType${roomName.isNotEmpty ? ' • $roomName' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.note,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  note,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'เกิดข้อผิดพลาด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'ไม่สามารถโหลดข้อมูลได้',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadActivityHistory,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'ลองใหม่',
                style: TextStyle(color: Colors.white),
              ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF5593E4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 70,
                color: const Color(0xFF9A2C2C).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ยังไม่มีประวัติการดำเนินการ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อคุณตรวจสอบหรือเปลี่ยนสถานะอุปกรณ์\nประวัติจะแสดงที่นี่',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
