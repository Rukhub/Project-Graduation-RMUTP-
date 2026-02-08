import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'krupan.dart';
import 'api_service.dart';
import 'add_equipment_quick.dart';
import 'report_problem_screen.dart';
import 'inspect_equipment_screen.dart';
import 'screens/inspection_history_screen.dart';
import 'qr_scanner_screen.dart';
import 'admin/user_management_screen.dart';
import 'app_drawer.dart';
import 'main.dart'; // สำหรับ LoginPage
import 'my_reports_screen.dart'; // เพิ่มใหม่: การแจ้งปัญหาของฉัน
import 'admin_activity_history_screen.dart'; // เพิ่มใหม่: ประวัติการดำเนินการสำหรับ Admin
import 'screens/admin_ticket_queue_screen.dart';
import 'services/firebase_service.dart';
import 'google_sign_in_service.dart';
// import 'models/user_model.dart';

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
  bool _recentExpanded = false;

  static const int _recentCollapsedLimit = 3;
  static const int _recentExpandedLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadUserProfile(); // Load Firebase Profile
    _checkRoleAndLoadData();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = ApiService().currentUser;
    final uid =
        currentUser?['uid']?.toString() ??
        currentUser?['user_id']?.toString() ??
        currentUser?['id']?.toString();

    if (uid != null) {
      final user = await FirebaseService().getUserProfile(uid);
      if (user != null && mounted) {
        setState(() {
          // Sync Firebase data to ApiService currentUser
          ApiService().currentUser = {
            ...ApiService().currentUser ?? {},
            'uid': user.uid,
            'fullname': user.fullname,
            'email': user.email,
            'role': user.role == 1 ? 'admin' : 'user', // UI compatibility
            'role_num': user.role,
            'photo_url': user.photoUrl,
            'is_approved': user.isApproved,
          };
        });
        debugPrint('👤 Profile loaded from Firebase: ${user.fullname}');
      }
    }
  }

  Future<void> _checkRoleAndLoadData() async {
    final role = ApiService().currentUser?['role'];
    final roleNum = ApiService().currentUser?['role_num'];

    if (role == 'admin' || roleNum == 1) {
      _loadDashboardStats();
    } else {
      _loadRecentReports();
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await FirebaseService().getAssetStats();

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
      final user = FirebaseAuth.instance.currentUser;
      final reporterId = user?.uid ?? '';
      if (reporterId.trim().isEmpty) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ (UID)');
      }

      // Load user specific reports via Firestore (by UID)
      final data = await FirebaseService().getReportsByReporterId(reporterId);

      if (mounted) {
        setState(() {
          recentReports = data;
          isLoadingReports = false;
          _recentExpanded = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent reports: $e');
      if (mounted) setState(() => isLoadingReports = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;
    bool isAdmin = user?['role'] == 'admin' || user?['role_num'] == 1;

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
              if (isAdmin) _buildAdminDashboard() else _buildUserDashboard(),

              const SizedBox(height: 20),

              // 2. Menu Items Section
              // Hide main items for User because they are already in the Dashboard
              if (isAdmin) ...[
                // ========== 📦 จัดการครุภัณฑ์ ==========
                _buildSectionHeader('📦 จัดการครุภัณฑ์'),
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

                // ========== 🔧 แจ้งซ่อม / ตรวจสอบ ==========
                const SizedBox(height: 16),
                _buildSectionHeader('🔧 แจ้งซ่อม / ตรวจสอบ'),
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
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/2838/2838838.png',
                  title: 'คิวงานแจ้งปัญหา',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminTicketQueueScreen(),
                      ),
                    );
                  },
                ),
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/3696/3696579.png',
                  title: 'ประวัติการรายงาน',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AdminActivityHistoryScreen(),
                      ),
                    );
                  },
                ),
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
                MenuItem(
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/892/892781.png',
                  title: 'ประวัติการตรวจสอบอุปกรณ์',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InspectionHistoryScreen(),
                      ),
                    );
                  },
                ),

                // ========== ⚙️ ระบบ ==========
                const SizedBox(height: 16),
                _buildSectionHeader('⚙️ ระบบ'),
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
              ],
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
            onPressed: () async {
              try {
                await GoogleSignInService().signOut();
              } catch (_) {}
              ApiService().currentUser = null;

              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
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

  // === SECTION HEADER ===
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
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
              MaterialPageRoute(builder: (context) => const KrupanScreen()),
            );
          },
        ),

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
            Row(
              children: [
                if (!isLoadingReports && recentReports.length > 3)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _recentExpanded = !_recentExpanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      foregroundColor: Colors.grey.shade700,
                    ),
                    child: Text(
                      _recentExpanded
                          ? 'ซ่อน'
                          : 'เพิ่มเติม (${math.max(0, math.min(recentReports.length, _recentExpandedLimit) - _recentCollapsedLimit)})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.green.shade200,
                ),
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
            itemCount: _recentExpanded
                ? math.min(recentReports.length, _recentExpandedLimit)
                : math.min(recentReports.length, _recentCollapsedLimit),
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final report = recentReports[index];
              return _buildMiniReportCard(report);
            },
          ),
        if (!isLoadingReports &&
            _recentExpanded &&
            recentReports.length > _recentExpandedLimit) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ขณะนี้มีทั้งหมด ${recentReports.length} รายการ (แสดงในหน้านี้ได้สูงสุด 5 รายการ) กรุณากดปุ่ม "ดูทั้งหมด" เพื่อดูรายการที่เหลือ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyReportsScreen(),
                      ),
                    );
                  },
                  child: const Text('ดูทั้งหมด'),
                ),
              ],
            ),
          ),
        ],
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
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget: Mini Report Card for Feed
  Widget _buildMiniReportCard(Map<String, dynamic> report) {
    final rawStatus = (report['report_status'] ?? 'pending').toString();
    final statusUi = _statusUi(rawStatus);

    final issue =
        (report['report_remark'] ??
                report['remark_report'] ??
                report['issue_detail'] ??
                report['issue'])
            ?.toString() ??
        'แจ้งปัญหา';

    final dateValue =
        report['reported_at'] ?? report['timestamp'] ?? report['report_date'];

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
            color: statusUi.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.build_circle_outlined, color: statusUi.color),
        ),
        title: Text(
          issue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${report['asset_id'] ?? ''} • ${_formatDateTime(dateValue)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusUi.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusUi.label,
            style: TextStyle(
              color: statusUi.color,
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

  ({Color color, Color bg, String label}) _statusUi(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'completed' || s == 'ปกติ' || s == 'ซ่อมเสร็จแล้ว') {
      return (
        color: Colors.green,
        bg: Colors.green.shade50,
        label: 'ซ่อมเสร็จ',
      );
    }
    if (s == 'repairing' || s == 'อยู่ระหว่างซ่อม' || s == 'กำลังซ่อม') {
      return (
        color: const Color(0xFFFF9800),
        bg: const Color(0xFFFFF3E0),
        label: 'กำลังซ่อม',
      );
    }
    if (s == 'cancelled' || s == 'ซ่อมไม่ได้') {
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
      return '$day/$month/$year';
    } catch (_) {
      return value.toString();
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
