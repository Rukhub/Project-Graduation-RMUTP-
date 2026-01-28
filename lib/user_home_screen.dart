import 'package:flutter/material.dart';
import '../krupan.dart';
import '../report_problem_screen.dart';
import '../qr_scanner_screen.dart';
import '../app_drawer.dart';
import '../my_reports_screen.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
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
                );
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
                  MaterialPageRoute(builder: (context) => const KrupanScreen()),
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
                );
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
                );
              },
            ),
          ],
        ),
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
