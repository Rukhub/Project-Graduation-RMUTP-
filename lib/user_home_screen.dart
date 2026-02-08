import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../krupan.dart';
import '../report_problem_screen.dart';
import '../qr_scanner_screen.dart';
import '../app_drawer.dart';
import '../my_reports_screen.dart';
import 'services/firebase_service.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? latestReport;
  bool isLoading = false;

  String _formatDateTime(dynamic value) {
    if (value == null) return '';
    try {
      DateTime? dt;
      if (value is Timestamp) {
        dt = value.toDate();
      } else if (value is DateTime) {
        dt = value;
      } else {
        dt = DateTime.tryParse(value.toString());
      }
      if (dt == null) return value.toString();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  ({Color color, Color bg, String label}) _statusUi(dynamic status) {
    final c = FirebaseService.reportStatusToCode(status);
    if (c == 3) {
      return (
        color: Colors.green,
        bg: Colors.green.shade50,
        label: 'ซ่อมเสร็จ',
      );
    }
    if (c == 2) {
      return (
        color: const Color(0xFFFF9800),
        bg: const Color(0xFFFFF3E0),
        label: 'กำลังซ่อม',
      );
    }
    if (c == 4) {
      return (
        color: const Color(0xFF6B7280),
        bg: const Color(0xFFF3F4F6),
        label: 'ซ่อมไม่ได้',
      );
    }
    return (
      color: const Color(0xFFEF4444),
      bg: const Color(0xFFFFEBEE),
      label: 'รอดำเนินการ',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLatestReport();
  }

  Future<void> _loadLatestReport() async {
    setState(() => isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.trim().isEmpty) return;

      final reports = await FirebaseService().getReportsByReporterId(uid);
      if (reports.isNotEmpty && mounted) {
        setState(() {
          latestReport = reports.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading latest report: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        title: const Padding(
          padding: EdgeInsets.only(left: 25),
          child: Text(
            'RMUTP',
            style: TextStyle(
              fontFamily: 'InknutAntiqua',
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 25),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 36),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLatestReport,
        color: const Color(0xFF9A2C2C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Latest Report Card
              _buildLatestReportSection(),

              const SizedBox(height: 10),
              // Link to see all
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyReportsScreen(),
                      ),
                    ).then(
                      (_) => _loadLatestReport(),
                    ); // Reload when coming back
                  },
                  child: Text(
                    'ดูทั้งหมด >',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Big Scan Button
              _buildBigButton(
                context,
                'สแกน QR Code เพื่อตรวจสอบ',
                Icons.qr_code_scanner,
                const Color(0xFF9A2C2C),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRScannerScreen(),
                    ),
                  ).then((_) => _loadLatestReport());
                },
              ),
              const SizedBox(height: 20),

              // Other actions
              _buildBigButton(
                context,
                'ดูรายการครุภัณฑ์',
                Icons.inventory_2_outlined,
                const Color(0xFF5593E4),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KrupanScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              _buildBigButton(
                context,
                'แจ้งปัญหา / ขัดข้อง',
                Icons.report_problem_outlined,
                const Color(0xFFE44F5A),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportProblemScreen(),
                    ),
                  ).then((_) => _loadLatestReport());
                },
              ),
              const SizedBox(height: 20),

              // เมนูใหม่: การแจ้งปัญหาของฉัน
              _buildBigButton(
                context,
                'การแจ้งปัญหาของฉัน',
                Icons.history,
                const Color(0xFF9C27B0),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyReportsScreen(),
                    ),
                  ).then((_) => _loadLatestReport());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestReportSection() {
    if (isLoading) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFF9A2C2C)),
      );
    }

    if (latestReport == null) {
      // Show "Normal" state
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ยังไม่มีรายการแจ้งซ่อม',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'อุปกรณ์ของคุณปกติดี!',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Show Latest Report Details
    final report = latestReport!;

    final rawStatus = report['report_status'] ?? report['status'] ?? 1;
    final statusUi = _statusUi(rawStatus);
    final assetId = report['asset_id']?.toString() ?? '-';
    final issue =
        (report['report_remark'] ??
                report['remark_report'] ??
                report['issue_detail'] ??
                report['issue'])
            ?.toString() ??
        '-';
    final dateValue =
        report['reported_at'] ?? report['timestamp'] ?? report['date'];
    final date = _formatDateTime(dateValue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: statusUi.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'การแจ้งปัญหาล่าสุด',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusUi.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusUi.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  statusUi.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusUi.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            assetId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            issue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              date,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
