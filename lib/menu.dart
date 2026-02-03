import 'package:flutter/material.dart';
import 'krupan.dart';
import 'api_service.dart';
import 'add_equipment_quick.dart';
import 'report_problem_screen.dart';
import 'inspect_equipment_screen.dart';
import 'qr_scanner_screen.dart';
import 'admin/user_management_screen.dart';
import 'app_drawer.dart';
import 'main.dart'; // สำหรับ LoginPage
import 'my_reports_screen.dart'; // เพิ่มใหม่: การแจ้งปัญหาของฉัน
import 'admin_activity_history_screen.dart'; // เพิ่มใหม่: ประวัติการดำเนินการสำหรับ Admin

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

 // Dashboard Stats
  int myScansCount = 0;
  int goodConditionCount = 0;
  int myReportsCount = 0;
  int brokenCount = 0;
  bool isLoadingStats = true;

  // User Reports (for Activity Feed)
  List<Map<String, dynamic>> recentReports = [];
  bool isLoadingReports = true;

  @override
  void initState() {
    super.initState();
    // Load based on role
    _checkRoleAndLoadData();
  }

  Future<void> _checkRoleAndLoadData() async {
    final role = ApiService().currentUser?['role'];
    if (role == 'admin') {
      _loadDashboardStats();
    } else {
      _loadRecentReports();
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await ApiService().getDashboardStats();

      if (mounted) {
        setState(() {
          myScansCount = stats['total'] ?? 0;
          goodConditionCount = stats['normal'] ?? 0;
          myReportsCount = stats['pending'] ?? 0;
          brokenCount = stats['damaged'] ?? 0;
          isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) setState(() => isLoadingStats = false);
    }
  }

  Future<void> _loadRecentReports() async {
    try {
      final currentUser = ApiService().currentUser;
      final reporterName =
          currentUser?['fullname'] ?? currentUser?['username'] ?? 'Unknown';
      
      // Load user specific reports
      final data = await ApiService().getMyReports(reporterName);

      if (mounted) {
        setState(() {
          // Take top 3 most recent
          recentReports = data.take(3).toList();
          isLoadingReports = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent reports: $e');
      if (mounted) setState(() => isLoadingReports = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = ApiService().currentUser?['role'] == 'admin';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),

      // ===== APP BAR =====
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
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
          ),
        ],
      ),

      // ===== BODY =====
      body: RefreshIndicator(
        onRefresh: () async {
          if (isAdmin) {
            await _loadDashboardStats();
          } else {
            await _loadRecentReports();
          }
        },
        color: const Color(0xFF9A2C2C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // 1. Dashboard Section (Switch based on Role)
              if (isAdmin)
                _buildAdminDashboard()
              else
                _buildUserDashboard(),

              const SizedBox(height: 20),

              // 2. Menu Items Section
              // Hide main items for User because they are already in the Dashboard
              if (isAdmin) ...[
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/9252/9252207.png',
                  title: 'ครุภัณฑ์',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KrupanScreen(),
                      ),
                    );
                  },
                ),
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/4108/4108996.png',
                  title: 'Scan QR Code - หาครุภัณฑ์',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRScannerScreen(),
                      ),
                    );
                  },
                ),
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/11873/11873385.png',
                  title: 'เพิ่มอุปกรณ์',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddEquipmentQuickScreen(),
                      ),
                    );
                  },
                ),
                 MenuItem(
                imageUrl:
                    'https://cdn-icons-png.flaticon.com/256/4960/4960785.png',
                title: 'แจ้งปัญหา / ขัดข้อง',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportProblemScreen(),
                    ),
                  );
                },
              ),
              ],

              // เมนูแตกต่างตาม Role (ส่วนท้าย)
              if (isAdmin)
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/3696/3696579.png',
                  title: 'ประวัติการดำเนินการ',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AdminActivityHistoryScreen(),
                      ),
                    );
                  },
                )
              else
                // For User: link to full history
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/2099/2099058.png',
                  title: 'ประวัติการแจ้งปัญหา (ทั้งหมด)',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyReportsScreen(),
                      ),
                    );
                  },
                ),

              if (isAdmin)
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/1256/1256650.png',
                  title: 'ระบบอนุมัติผู้ใช้',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserManagementScreen(),
                      ),
                    );
                  },
                ),

              if (isAdmin)
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/256/11726/11726423.png',
                  title: 'ตรวจสอบอุปกรณ์',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InspectEquipmentScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),

      // ===== ปุ่มออกจากระบบ =====
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text(
              'ออกจากระบบ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9A2C2C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // === ADMIN DASHBOARD ===
  Widget _buildAdminDashboard() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SummaryCard(
          title: 'จำนวนครุภัณฑ์\nทั้งหมด',
          value: isLoadingStats ? '-' : '$myScansCount',
          color: const Color(0xFF5593E4),
          icon: Icons.qr_code_scanner,
        ),
        SummaryCard(
          title: 'จำนวนครุภัณฑ์ที่\nตรวจสอบแล้ว',
          value: isLoadingStats ? '-' : '$goodConditionCount',
          color: const Color(0xFF99CD60),
          icon: Icons.check_circle_outline,
        ),
        SummaryCard(
          title: 'กำลังตรวจสอบ /\nกำลังดำเนินการ',
          value: isLoadingStats ? '-' : '$myReportsCount',
          color: const Color(0xFFFECC52),
          icon: Icons.access_time_filled,
        ),
        SummaryCard(
          title: 'จำนวนครุภัณฑ์ที่\nเสียหาย',
          value: isLoadingStats ? '-' : '$brokenCount',
          color: const Color(0xFFE44F5A),
          icon: Icons.broken_image_outlined,
        ),
      ],
    );
  }

  // === USER DASHBOARD (NEW HYBRID DESIGN) ===
  Widget _buildUserDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Quick Actions (Buttons)
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'สแกน QR',
                icon: Icons.qr_code_scanner,
                color1: const Color(0xFF5593E4),
                color2: const Color(0xFF3B7BC4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRScannerScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'แจ้งปัญหา',
                icon: Icons.report_problem,
                color1: const Color(0xFFE44F5A),
                color2: const Color(0xFFC63642),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportProblemScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Secondary Action: Browse Rooms
        _buildFullWidthActionCard(
            title: 'ค้นหาครุภัณฑ์ตามรายห้อง',
            icon: Icons.inventory_2,
            color: const Color(0xFF99CD60), // Green
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KrupanScreen(),
                ),
              );
            }),

        const SizedBox(height: 30),

        // 2. Report Feed (Context)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'การแจ้งปัญหาล่าสุด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyReportsScreen(),
                      ),
                    );
              },
              child: Text(
                'ดูทั้งหมด >',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Feed List
        if (isLoadingReports)
          const Center(child: CircularProgressIndicator())
        else if (recentReports.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green.shade200),
                const SizedBox(height: 10),
                const Text(
                  'ยังไม่มีรายการแจ้งซ่อม\nอุปกรณ์ของคุณปกติดี!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentReports.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final report = recentReports[index];
              return _buildMiniReportCard(report);
            },
          ),
      ],
    );
  }

  // Widget: Action Button (Half Width)
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 120, // Tall enough to be a big button
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color2.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget: Full Width Button
  Widget _buildFullWidthActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 80,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget: Mini Report Card for Feed
  Widget _buildMiniReportCard(Map<String, dynamic> report) {
    String status = report['status'] ?? 'Unknown';
    // ⭐ NEW: ดึงสถานะปัจจุบันของ Asset
    String assetCurrentStatus = report['asset_current_status']?.toString() ?? '';

    // ⭐ FIX: ถ้า Asset กำลังซ่อม ให้ถือว่าเป็น 'กำลังซ่อม' (ถึงแม้ Report จะเป็น Pending)
    if ((status == 'รอดำเนินการ' || status == 'รอตรวจสอบ' || status == 'ชำรุด') &&
        (assetCurrentStatus == 'อยู่ระหว่างซ่อม' || assetCurrentStatus == 'กำลังซ่อม')) {
      status = 'อยู่ระหว่างซ่อม';
    }

    Color statusColor;
    String statusLabel;

    // ✅ รองรับสถานะใหม่จาก Backend
    if (status == 'ปกติ' || status == 'ซ่อมเสร็จแล้ว' || status == 'ดำเนินการเสร็จสิ้น') {
      statusColor = Colors.green;
      statusLabel = 'ซ่อมเสร็จแล้ว';
    } else if (status == 'อยู่ระหว่างซ่อม' || status == 'กำลังดำเนินการ' || status == 'กำลังซ่อม') {
      statusColor = Colors.orange;
      statusLabel = 'กำลังซ่อม';
    } else {
      // รวม 'รอดำเนินการ', 'ชำรุด', 'รอตรวจสอบ', etc.
      statusColor = Colors.amber;
      statusLabel = 'รอซ่อม';
    }

    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.build_circle_outlined, color: statusColor),
        ),
        title: Text(
          report['issue_detail'] ?? 'แจ้งปัญหา',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
           '${report['asset_id'] ?? ''} • ${_formatDate(report['report_date'])}',
           style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        onTap: () {
             // Navigate to specific detail if possible, currently sticking to MyReports for simplicity
             // or could navigate to EquipmentDetailScreen like in MyReportsScreen
             // For now, let's open MyReportsScreen as it's safer
             Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyReportsScreen()),
             );
        },
      ),
    );
  }
  
  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final date = DateTime.parse(dateValue.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData? icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // ตัดส่วนเกินของ Icon ที่ล้นออก
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Watermark Icon (พื้นหลัง)
          if (icon != null)
            Positioned(
              right: -15, // ขยับให้ล้นออกขวานิดหน่อย
              bottom: -15, // ขยับให้ล้นลงล่างนิดหน่อย
              child: Transform.rotate(
                angle: -0.2, // เอียงเล็กน้อย (-11 องศา)
                child: Icon(
                  icon,
                  size: 90, // ขนาดใหญ่สะใจ
                  color: Colors.white.withValues(alpha: 0.2), // โปร่งใส
                ),
              ),
            ),

          // 2. Content Elements (ข้อความและตัวเลข)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 15, // ปรับขยายตามคำขอ (แก้ตรงนี้)
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                ),
                // Value
                Align(
                  alignment: Alignment.bottomLeft, // ชิดซ้ายล่าง
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 46, // ปรับขยายตัวเลข (แก้ตรงนี้)
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== MENU ITEM =====
class MenuItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final VoidCallback onTap;

  const MenuItem({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Image.network(imageUrl, width: 40, height: 40),
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
