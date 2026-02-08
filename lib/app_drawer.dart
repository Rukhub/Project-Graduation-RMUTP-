import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'menu.dart';
import 'krupan.dart';
import 'add_equipment_quick.dart';
import 'inspect_equipment_screen.dart';
import 'report_problem_screen.dart';
import 'api_service.dart';
import 'admin/user_management_screen.dart';
import 'google_sign_in_service.dart';
import 'services/firebase_service.dart';
import 'models/user_model.dart';
import 'main.dart';
import 'screens/inspection_history_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static const String _purgeAllowedEmail = 'rattanan-b@rmutp.ac.th';

  @override
  Widget build(BuildContext context) {
    final userEmail = ApiService().currentUser?['email']?.toString().trim();
    final bool canPurge = userEmail == _purgeAllowedEmail;

    return Drawer(
      backgroundColor: const Color(0xFF9A2C2C),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text(
                        'R',
                        style: TextStyle(
                          fontFamily: 'InknutAntiqua',
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9A2C2C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RMUTP',
                        style: TextStyle(
                          fontFamily: 'InknutAntiqua',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'ระบบจัดการครุภัณฑ์',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),

            // ระบบจัดการ Section
            _buildSectionHeader('ระบบจัดการ'),
            const SizedBox(height: 5),

            // Menu Items
            _buildMenuItem(
              context,
              icon: Icons.home_outlined,
              title: 'หน้าแรก',
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MenuScreen()),
                  (route) => false,
                );
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'ครุภัณฑ์',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const KrupanScreen()),
                );
              },
            ),

            // เมนูสำหรับ Admin เท่านั้น
            if (ApiService().currentUser?['role'] == 'admin' ||
                ApiService().currentUser?['role_num'] == 1)
              _buildMenuItem(
                context,
                icon: Icons.add_circle_outline,
                title: 'เพิ่มอุปกรณ์',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEquipmentQuickScreen(),
                    ),
                  );
                },
              ),

            // เมนูสำหรับ Admin เท่านั้น
            if (ApiService().currentUser?['role'] == 'admin' ||
                ApiService().currentUser?['role_num'] == 1)
              _buildMenuItem(
                context,
                icon: Icons.verified_outlined,
                title: 'ตรวจสอบอุปกรณ์',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InspectEquipmentScreen(),
                    ),
                  );
                },
              ),

            if (ApiService().currentUser?['role'] == 'admin' ||
                ApiService().currentUser?['role_num'] == 1)
              _buildMenuItem(
                context,
                icon: Icons.history,
                title: 'ประวัติการตรวจสอบอุปกรณ์',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InspectionHistoryScreen(),
                    ),
                  );
                },
              ),

            if (ApiService().currentUser?['role'] == 'admin' ||
                ApiService().currentUser?['role_num'] == 1)
              _buildMenuItem(
                context,
                icon: Icons.manage_accounts_outlined,
                title: 'ระบบอนุมัติผู้ใช้',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  );
                },
              ),

            _buildMenuItem(
              context,
              icon: Icons.report_problem_outlined,
              title: 'แจ้งปัญหา',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportProblemScreen(),
                  ),
                );
              },
            ),

            if (canPurge)
              _buildMenuItem(
                context,
                icon: Icons.delete_forever_outlined,
                title: 'ล้างประวัติแจ้งซ่อม',
                onTap: () {
                  Navigator.pop(context);
                  _showPurgeReportsHistoryDialog(context);
                },
              ),

            const Divider(color: Colors.white24, height: 30),

            // โปรไฟล์ Section
            _buildSectionHeader('บัญชี'),
            const SizedBox(height: 5),

            _buildMenuItem(
              context,
              icon: Icons.person_outline,
              title: 'ตั้งค่าโปรไฟล์',
              onTap: () {
                Navigator.pop(context);
                _showProfileDialog(context);
              },
            ),

            const Spacer(),

            // ออกจากระบบ
            Container(
              margin: const EdgeInsets.all(20),
              child: Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'ออกจากระบบ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showPurgeReportsHistoryDialog(BuildContext context) async {
    int selectedCount = 50;
    final countController = TextEditingController(
      text: selectedCount.toString(),
    );
    final confirmController = TextEditingController();
    bool isDeleting = false;
    String selectedCollection = 'reports_history';

    await showDialog<void>(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleDelete() async {
              final int? parsed = int.tryParse(countController.text.trim());
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('กรุณาระบุจำนวนให้ถูกต้อง')),
                );
                return;
              }
              if (confirmController.text.trim() != 'DELETE') {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณาพิมพ์ DELETE เพื่อยืนยัน'),
                  ),
                );
                return;
              }

              setDialogState(() => isDeleting = true);
              try {
                final deleted = await FirebaseService()
                    .deleteDocsFromCollection(
                      collection: selectedCollection,
                      count: parsed,
                    );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ลบสำเร็จ $deleted รายการ จาก $selectedCollection',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
                }
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isDeleting = false);
                }
              }
            }

            Widget buildQuickButton(int v) {
              return Expanded(
                child: OutlinedButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          setDialogState(() {
                            selectedCount = v;
                            countController.text = v.toString();
                          });
                        },
                  child: Text('$v'),
                ),
              );
            }

            return AlertDialog(
              title: const Text('ล้างประวัติแจ้งซ่อม'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('เลือก collection และจำนวนที่จะลบ'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCollection,
                    items: const [
                      DropdownMenuItem(
                        value: 'reports_history',
                        child: Text('reports_history'),
                      ),
                      DropdownMenuItem(
                        value: 'audits_history',
                        child: Text('audits_history'),
                      ),
                    ],
                    onChanged: isDeleting
                        ? null
                        : (v) {
                            if (v == null) return;
                            setDialogState(() {
                              selectedCollection = v;
                            });
                          },
                    decoration: const InputDecoration(
                      labelText: 'Collection',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      buildQuickButton(10),
                      const SizedBox(width: 8),
                      buildQuickButton(50),
                      const SizedBox(width: 8),
                      buildQuickButton(100),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countController,
                    enabled: !isDeleting,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนที่จะลบ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('พิมพ์ DELETE เพื่อยืนยันการลบ'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    enabled: !isDeleting,
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isDeleting ? null : handleDelete,
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ลบ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Colors.white24, height: 1)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 15),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProfileDialog(BuildContext context) async {
    final uid =
        ApiService().currentUser?['uid']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    UserModel? profile;
    if (uid.trim().isNotEmpty) {
      profile = await FirebaseService().getUserProfileByUid(uid);
    }

    final name =
        profile?.fullname ??
        ApiService().currentUser?['fullname'] ??
        'ผู้ใช้งาน';
    final email = profile?.email ?? ApiService().currentUser?['email'] ?? '';

    final nameController = TextEditingController(text: name);
    final emailController = TextEditingController(text: email);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.person, color: Color(0xFF9A2C2C), size: 28),
              SizedBox(width: 10),
              Text(
                'ตั้งค่าโปรไฟล์',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF9A2C2C),
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อ-นามสกุล',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                readOnly: true, // Email from Google should be read-only
                decoration: InputDecoration(
                  labelText: 'อีเมล (Google Account)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกชื่อ-นามสกุล'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                bool ok = true;
                final id = uid.trim();
                if (id.isNotEmpty) {
                  ok = await FirebaseService().updateUserProfileFields(id, {
                    'fullname': newName,
                  });
                }

                if (!context.mounted) return;
                Navigator.pop(context);

                if (ok) {
                  ApiService().currentUser = {
                    ...ApiService().currentUser ?? {},
                    'uid': id,
                    'fullname': newName,
                    'email': email,
                  };
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('บันทึกโปรไฟล์สำเร็จ'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('บันทึกโปรไฟล์ไม่สำเร็จ'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2C2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'บันทึก',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ออกจากระบบ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
