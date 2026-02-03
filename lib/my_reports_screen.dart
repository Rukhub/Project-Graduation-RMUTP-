import 'package:flutter/material.dart';
import 'api_service.dart';
import 'equipment_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<Map<String, dynamic>> reports = [];
  bool isLoading = true;
  String? errorMessage;

  // สถิติ
  int totalReports = 0;
  int pendingCount = 0; // ชำรุด = รอดำเนินการ
  int repairingCount = 0; // อยู่ระหว่างซ่อม = กำลังซ่อม
  int fixedCount = 0; // ปกติ = ซ่อมเสร็จแล้ว

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // ใช้ชื่อผู้ใช้ที่ล็อกอินอยู่
      final currentUser = ApiService().currentUser;
      final reporterName =
          currentUser?['fullname'] ?? currentUser?['username'] ?? 'Unknown';

      final data = await ApiService().getMyReports(reporterName);

      // คำนวณสถิติ
      int pending = 0;
      int repairing = 0;
      int fixed = 0;

      for (var report in data) {
        // ⭐ NEW: Check real-time asset status
        final assetCurrentStatus = report['asset_current_status']?.toString();
        var status = report['status']?.toString() ?? '';

        // DEBUG PRINT
        debugPrint(
          '🔍 Report: ${report['report_id']} | Asset: ${report['asset_id']}',
        );
        debugPrint('   - Report Status: $status');
        debugPrint('   - Asset Current Status: $assetCurrentStatus');

        // ถ้า Asset กำลังซ่อม แต่ Report ยังขึ้นรอ -> ให้ถือว่ากำลังซ่อม
        if ((status == 'รอดำเนินการ' ||
                status == 'รอตรวจสอบ' ||
                status == 'ชำรุด') &&
            (assetCurrentStatus == 'อยู่ระหว่างซ่อม' ||
                assetCurrentStatus == 'กำลังซ่อม')) {
          status = 'อยู่ระหว่างซ่อม';
          report['status'] = status; // Update local data for display
        }

        // นับ 'ชำรุด' หรือค่าว่าง/null/รอดำเนินการ เป็น 'รอดำเนินการ'
        if (status == 'ชำรุด' ||
            status.isEmpty ||
            status == 'รอตรวจสอบ' ||
            status == 'null' ||
            status == 'รอดำเนินการ') {
          pending++;
        } else if (status == 'อยู่ระหว่างซ่อม' || status == 'กำลังดำเนินการ') {
          repairing++;
        } else if (status == 'ปกติ' || status == 'ซ่อมเสร็จแล้ว') {
          fixed++;
        }
      }

      if (mounted) {
        setState(() {
          reports = data;
          totalReports = data.length;
          pendingCount = pending;
          repairingCount = repairing;
          fixedCount = fixed;
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
      // Format: dd/MM/yyyy HH:mm
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

  // แปลงสถานะ Asset เป็นสถานะแสดงผลสำหรับ User
  Map<String, dynamic> _getReportStatus(String assetStatus) {
    switch (assetStatus) {
      case 'ชำรุด':
      case 'รอดำเนินการ': // เพิ่ม case ใหม่
      case 'รอตรวจสอบ':
        return {
          'label': 'รอดำเนินการ',
          'color': Colors.amber,
          'icon': Icons.hourglass_empty,
          'bgColor': Colors.amber.shade50,
        };
      case 'อยู่ระหว่างซ่อม':
      case 'กำลังดำเนินการ': // เพิ่ม case ใหม่
        return {
          'label': 'กำลังซ่อม',
          'color': Colors.orange,
          'icon': Icons.build_circle,
          'bgColor': Colors.orange.shade50,
        };
      case 'ปกติ':
      case 'ซ่อมเสร็จแล้ว': // เพิ่ม case ใหม่
        return {
          'label': 'ซ่อมเสร็จแล้ว',
          'color': Colors.green,
          'icon': Icons.check_circle,
          'bgColor': Colors.green.shade50,
        };
      default:
        // กรณีไม่ระบุสถานะ หรือ status เป็น null ให้ถือว่าเป็น "รอการตรวจสอบ"
        return {
          'label': 'รอการตรวจสอบ',
          'color': Colors.amber.shade700,
          'icon': Icons.hourglass_top,
          'bgColor': Colors.amber.shade50,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        foregroundColor: Colors.white,
        title: const Text(
          'การแจ้งปัญหาของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildErrorState()
          : reports.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummarySection(),
                    const SizedBox(height: 24),
                    _buildReportsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: Colors.grey.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              'สรุปสถานะ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'ทั้งหมด',
                totalReports.toString(),
                Colors.blue,
                Icons.list_alt,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'รอดำเนินการ',
                pendingCount.toString(),
                Colors.amber,
                Icons.hourglass_empty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'กำลังซ่อม',
                repairingCount.toString(),
                Colors.orange,
                Icons.build_circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'ซ่อมเสร็จแล้ว',
                fixedCount.toString(),
                Colors.green,
                Icons.check_circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.format_list_bulleted,
              color: Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'รายการแจ้งปัญหา',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalReports รายการ',
                style: const TextStyle(
                  color: Color(0xFF9A2C2C),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reports.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildReportCard(reports[index]),
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final assetStatus = report['status']?.toString() ?? '';
    final statusInfo = _getReportStatus(assetStatus);

    final assetId = report['asset_id']?.toString() ?? '-';
    final brandModel = report['brand_model']?.toString() ?? '-';
    final assetType = report['asset_type']?.toString() ?? '-';
    final issueDetail = report['issue_detail']?.toString() ?? '-';
    final reportDate = _formatDate(report['report_date']);
    final imageUrl = report['image_url']?.toString();

    // ข้อมูลจาก API ใหม่ของโบ
    final locationId = report['location_id'];
    final roomName = report['room_name']?.toString() ?? '';
    final floor = report['floor']?.toString() ?? '';
    final reporterName = report['reporter_name']?.toString();

    return GestureDetector(
      onTap: () {
        // นำทางไปหน้ารายละเอียดครุภัณฑ์ - ส่งข้อมูลครบ
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EquipmentDetailScreen(
              equipment: {
                'asset_id': assetId,
                'brand_model': brandModel,
                'type': assetType,
                'status': assetStatus,
                'location_id': locationId,
                'reporter_name': reporterName,
                'reporterName': reporterName,
                'issue_detail': issueDetail,
                'reportReason': issueDetail,
                'report_image': imageUrl,
              },
              roomName: roomName.isNotEmpty
                  ? (floor.isNotEmpty
                        ? '$roomName (${floor.startsWith('ชั้น') ? floor : 'ชั้น $floor'})'
                        : roomName)
                  : 'ไม่ระบุห้อง',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (statusInfo['color'] as Color).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusInfo['bgColor'],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    statusInfo['icon'],
                    color: statusInfo['color'],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusInfo['label'],
                    style: TextStyle(
                      color: statusInfo['color'],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    reportDate,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image or placeholder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code_2,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              assetId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$assetType • $brandModel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.report_problem,
                                size: 16,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  issueDetail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 30),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีการแจ้งปัญหา',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เมื่อคุณแจ้งปัญหาอุปกรณ์ จะแสดงที่นี่',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'เกิดข้อผิดพลาด',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'ไม่สามารถโหลดข้อมูลได้',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองอีกครั้ง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9A2C2C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
