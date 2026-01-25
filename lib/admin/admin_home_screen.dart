import 'package:flutter/material.dart';
import '../krupan.dart';
import '../add_equipment_quick.dart';
import '../report_problem_screen.dart';
import '../inspect_equipment_screen.dart';
import '../qr_scanner_screen.dart';
import 'user_management_screen.dart';
import '../app_drawer.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        title: const Padding(
          padding: EdgeInsets.only(left: 25),
          child: Text(
            'RMUTP (Admin)',
            style: TextStyle(
              fontFamily: 'InknutAntiqua',
              fontSize: 32,
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
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Dashboard (Admin Only)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                SummaryCard(
                  title: 'จำนวนครุภัณฑ์ทั้งมด',
                  value: '7',
                  color: Color(0xFF5593E4),
                ),
                SummaryCard(
                  title: 'ตรวจสอบแล้ว',
                  value: '4',
                  color: Color(0xFF99CD60),
                ),
                SummaryCard(
                  title: 'กำลังตรวจสอบ',
                  value: '1',
                  color: Color(0xFFFECC52),
                ),
                SummaryCard(
                  title: 'เสียหาย',
                  value: '2',
                  color: Color(0xFFE44F5A),
                ),
              ],
            ),
            const SizedBox(height: 40),

            _buildMenuGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        // Manage Users
        _buildMenuCard(
          context,
          'ระบบอนุมัติผู้ใช้',
          Icons.manage_accounts,
          Colors.purple,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserManagementScreen(),
              ),
            );
          },
        ),
        _buildMenuCard(
          context,
          'จัดการห้อง/ครุภัณฑ์',
          Icons.inventory_2,
          Colors.blue,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const KrupanScreen()),
            );
          },
        ),
        _buildMenuCard(
          context,
          'เพิ่มอุปกรณ์',
          Icons.add_circle,
          Colors.green,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEquipmentQuickScreen(),
              ),
            );
          },
        ),
        _buildMenuCard(
          context,
          'ตรวจสอบอุปกรณ์',
          Icons.verified,
          Colors.orange,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InspectEquipmentScreen(),
              ),
            );
          },
        ),
        _buildMenuCard(
          context,
          'รายงานปัญหา',
          Icons.report_problem,
          Colors.red,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReportProblemScreen(),
              ),
            );
          },
        ),
        _buildMenuCard(
          context,
          'สแกน QR Code',
          Icons.qr_code_scanner,
          Colors.teal,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QRScannerScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
