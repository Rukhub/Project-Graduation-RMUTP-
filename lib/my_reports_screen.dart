import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';
import 'services/firebase_service.dart';
import 'equipment_detail_screen.dart';
import 'app_drawer.dart';
import 'screens/report_detail_screen.dart';

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
  int pendingCount = 0;
  int repairingCount = 0;
  int completedCount = 0;
  int cancelledCount = 0;

  String _selectedFilter = 'all';

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
      final user = FirebaseAuth.instance.currentUser;
      final reporterId = user?.uid ?? '';
      if (reporterId.trim().isEmpty) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ (UID)');
      }

      final data = await FirebaseService().getReportsByReporterId(reporterId);

      // คำนวณสถิติ
      int pending = 0;
      int repairing = 0;
      int completed = 0;
      int cancelled = 0;

      for (var report in data) {
        final status = FirebaseService.reportStatusToCode(
          report['report_status'],
        );
        if (status == 1) {
          pending++;
        } else if (status == 2) {
          repairing++;
        } else if (status == 3) {
          completed++;
        } else if (status == 4) {
          cancelled++;
        }
      }

      if (mounted) {
        setState(() {
          reports = data;
          totalReports = data.length;
          pendingCount = pending;
          repairingCount = repairing;
          completedCount = completed;
          cancelledCount = cancelled;
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
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else {
        date = DateTime.parse(dateValue.toString());
      }
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

  @override
  Widget build(BuildContext context) {
    final filteredReports = _applyFilter(reports, _selectedFilter);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: 'เมนู',
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
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
                    const SizedBox(height: 12),
                    _buildFilterButtons(),
                    const SizedBox(height: 24),
                    _buildReportsSection(filteredReports),
                  ],
                ),
              ),
            ),
    );
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> source,
    String filter,
  ) {
    if (filter == 'all') return source;
    return source.where((r) {
      final code = FirebaseService.reportStatusToCode(r['report_status']);
      if (filter == 'pending') return code == 1;
      if (filter == 'repairing') return code == 2;
      if (filter == 'completed') return code == 3;
      if (filter == 'cancelled') return code == 4;
      return false;
    }).toList();
  }

  Widget _buildFilterButtons() {
    final items = <Map<String, dynamic>>[
      {
        'key': 'all',
        'label': 'ทั้งหมด',
        'color': Colors.blue,
        'count': totalReports,
      },
      {
        'key': 'pending',
        'label': 'รอดำเนินการ',
        'color': const Color(0xFFEF4444),
        'count': pendingCount,
      },
      {
        'key': 'repairing',
        'label': 'กำลังซ่อม',
        'color': const Color(0xFFFF9800),
        'count': repairingCount,
      },
      {
        'key': 'completed',
        'label': 'ซ่อมเสร็จ',
        'color': const Color(0xFF16A34A),
        'count': completedCount,
      },
      {
        'key': 'cancelled',
        'label': 'ซ่อมไม่ได้',
        'color': const Color(0xFF6B7280),
        'count': cancelledCount,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((it) {
          final key = it['key'] as String;
          final label = it['label'] as String;
          final Color color = it['color'] as Color;
          final int count = it['count'] as int;
          final bool selected = _selectedFilter == key;
          final bool isAll = key == 'all';

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() {
                  _selectedFilter = key;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isAll ? 16 : 14,
                  vertical: isAll ? 10 : 9,
                ),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? color : Colors.grey.shade200,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isAll ? 13 : 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'ทั้งหมด $totalReports',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.25,
          children: [
            _buildStatCard(
              'รอดำเนินการ',
              pendingCount.toString(),
              const Color(0xFFEF4444),
              Icons.notification_important,
            ),
            _buildStatCard(
              'กำลังซ่อม',
              repairingCount.toString(),
              const Color(0xFFFF9800),
              Icons.build_circle,
            ),
            _buildStatCard(
              'ซ่อมเสร็จ',
              completedCount.toString(),
              const Color(0xFF16A34A),
              Icons.check_circle,
            ),
            _buildStatCard(
              'ซ่อมไม่ได้',
              cancelledCount.toString(),
              const Color(0xFF6B7280),
              Icons.cancel,
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
      padding: const EdgeInsets.all(12),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSection(List<Map<String, dynamic>> visibleReports) {
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
                '${visibleReports.length} รายการ',
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
          itemCount: visibleReports.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = visibleReports[index];
            return _buildUserReportCard(
              report: report,
              onTap: () {
                final reportId = report['id']?.toString() ?? '';
                if (reportId.trim().isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportDetailScreen(
                      reportId: reportId,
                      userRole: 0,
                      readOnly: true,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _statusTextForUser(dynamic status) {
    final code = FirebaseService.reportStatusToCode(status);
    if (code == 1) return 'รอดำเนินการ';
    if (code == 2) return 'กำลังซ่อม';
    if (code == 3) return 'ซ่อมเสร็จ';
    if (code == 4) return 'ซ่อมไม่ได้';
    return 'ไม่ทราบสถานะ';
  }

  Color _statusColorForUser(dynamic status) {
    final code = FirebaseService.reportStatusToCode(status);
    if (code == 1) return const Color(0xFFEF4444);
    if (code == 2) return const Color(0xFFFF9800);
    if (code == 3) return const Color(0xFF16A34A);
    if (code == 4) return const Color(0xFF6B7280);
    return Colors.grey;
  }

  Color _statusBgColorForUser(dynamic status) {
    final code = FirebaseService.reportStatusToCode(status);
    if (code == 1) return const Color(0xFFFFEBEE);
    if (code == 2) return const Color(0xFFFFF3E0);
    if (code == 3) return const Color(0xFFE8F5E9);
    if (code == 4) return const Color(0xFFF3F4F6);
    return Colors.grey.shade100;
  }

  String _formatReportedAt(Map<String, dynamic> report) {
    final dynamic ts = report['reported_at'] ?? report['timestamp'];
    return _formatDate(ts);
  }

  Widget _buildUserReportCard({
    required Map<String, dynamic> report,
    required VoidCallback onTap,
  }) {
    final dynamic status = FirebaseService.reportStatusToCode(
      report['report_status'],
    );
    final Color statusColor = _statusColorForUser(status);
    final Color statusBg = _statusBgColorForUser(status);
    final String assetId = report['asset_id']?.toString() ?? 'ไม่ระบุรหัส';
    final String issue =
        (report['report_remark'] ??
                report['remark_report'] ??
                report['issue_detail'] ??
                report['issue'])
            ?.toString() ??
        '-';
    final String img = (report['report_image_url'])?.toString().trim() ?? '';
    final String dateText = _formatReportedAt(report);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 64,
                color: Colors.grey.shade100,
                child: img.isNotEmpty
                    ? Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                          );
                        },
                      )
                    : Icon(Icons.image_outlined, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          assetId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _statusTextForUser(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (issue.isNotEmpty) ...[
                    Text(
                      issue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
