import 'package:flutter/material.dart';
import '../krupan.dart';
import '../report_problem_screen.dart';
import '../qr_scanner_screen.dart';
import '../app_drawer.dart';
import '../my_reports_screen.dart';
import '../api_service.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? latestReport;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLatestReport();
  }

  Future<void> _loadLatestReport() async {
    setState(() => isLoading = true);
    try {
      final user = ApiService().currentUser;
      final username = user?['fullname'] ?? user?['username'] ?? '';

      if (username.isNotEmpty) {
        final reports = await ApiService().getMyReports(username);
        if (reports.isNotEmpty && mounted) {
          // Sort or just take the first one assuming API returns sorted
          setState(() {
            latestReport = reports.first;
          });
        }
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
    final assetId = report['asset_id'] ?? '-';
    // Use asset status from API or fallback to report status
    final assetCurrentStatus = report['asset_current_status']?.toString();
    var rawStatus = report['status']?.toString() ?? 'รอตรวจสอบ';

    debugPrint(
      '🏠 Home: rawStatus=$rawStatus, assetStatus=$assetCurrentStatus',
    );

    // ⭐ FIX: ถ้า Asset กำลังซ่อม ให้แสดงว่ากำลังซ่อม (เหมือนใน MyReportsScreen)
    if ((rawStatus == 'รอดำเนินการ' ||
            rawStatus == 'รอตรวจสอบ' ||
            rawStatus == 'ชำรุด') &&
        (assetCurrentStatus == 'อยู่ระหว่างซ่อม' ||
            assetCurrentStatus == 'กำลังซ่อม')) {
      rawStatus = 'อยู่ระหว่างซ่อม';
    }

    // Determine color and label based on status
    Color statusColor;
    Color statusBgColor;
    String statusLabel;

    if (rawStatus == 'ปกติ' ||
        rawStatus == 'Normal' ||
        rawStatus == 'ซ่อมเสร็จแล้ว' ||
        rawStatus == 'ดำเนินการเสร็จสิ้น') {
      statusColor = Colors.green;
      statusBgColor = Colors.green.shade50;
      statusLabel = 'ซ่อมเสร็จแล้ว'; // หรือ 'ปกติ'
    } else if (rawStatus == 'อยู่ระหว่างซ่อม' ||
        rawStatus == 'Repairing' ||
        rawStatus == 'กำลังดำเนินการ') {
      statusColor = Colors.amber.shade700;
      statusBgColor = Colors.amber.shade50;
      statusLabel = 'กำลังซ่อม';
    } else if (rawStatus == 'ชำรุด' || rawStatus == 'Broken') {
      statusColor = Colors.red;
      statusBgColor = Colors.red.shade50;
      statusLabel = 'รอการตรวจสอบ';
    } else {
      // DefaultFor 'รอดำเนินการ' / 'รอตรวจสอบ' / Other
      statusColor = Colors.amber.shade700;
      statusBgColor = Colors.amber.shade50;
      statusLabel = 'รอดำเนินการ';
    }

    final issue = report['issue_detail'] ?? '-';
    final date = (report['report_date'] ?? '').split('T').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusBgColor),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  rawStatus == 'ปกติ'
                      ? Icons.check_circle_outline
                      : Icons.broken_image_outlined,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assetId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      issue,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
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
