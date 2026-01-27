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

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await ApiService().getDashboardStats();

      if (mounted) {
        setState(() {
          myScansCount =
              stats['total'] ??
              0; // ในที่นี้ Total คือจำนวนที่สแกน/ทั้งหมด ตาม API Dashboard
          goodConditionCount = stats['normal'] ?? 0;
          myReportsCount = stats['pending'] ?? 0; // หรือ issues
          brokenCount = stats['damaged'] ?? 0;
          isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) setState(() => isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          padding: EdgeInsets.only(left: 25), // ขยับ RMUTP มาทางขวา
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
            padding: const EdgeInsets.only(right: 25), // ⭐ ลดจากขอบขวา
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
        onRefresh: _loadDashboardStats,
        color: const Color(0xFF9A2C2C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // แสดง Dashboard เฉพาะ Admin
              // Dashboard (แสดงสำหรับทุกคน - Personalized)
              GridView.count(
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
                    icon: Icons
                        .access_time_filled, // Changed icon to match "Pending/Processing" better
                  ),
                  SummaryCard(
                    title: 'จำนวนครุภัณฑ์ที่\nเสียหาย',
                    value: isLoadingStats ? '-' : '$brokenCount',
                    color: const Color(0xFFE44F5A),
                    icon: Icons.broken_image_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 20),

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

              // เมนูสำหรับ Admin เท่านั้น
              if (ApiService().currentUser?['role'] == 'admin')
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

              if (ApiService().currentUser?['role'] == 'admin')
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

              // เมนูสำหรับ Admin เท่านั้น
              if (ApiService().currentUser?['role'] == 'admin')
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
              // กลับไปหน้า Login (ออกจากระบบ)
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
}

// ===== SUMMARY CARD (Redesigned - Watermark Style) =====
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