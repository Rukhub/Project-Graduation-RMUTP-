import 'package:flutter/material.dart';
import 'krupan.dart';
import 'add_equipment_quick.dart';
import 'report_problem_screen.dart';
import 'inspect_equipment_screen.dart';
import 'app_drawer.dart';
import 'main.dart';  // สำหรับ LoginPage

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                SummaryCard(
                  title: 'จำนวนครุภัณฑ์ทั้งหมด',
                  value: '7',
                  color: Color(0xFF5593E4),
                ),
                SummaryCard(
                  title: 'จำนวนครุภัณฑ์ที่ตรวจสอบแล้ว',
                  value: '4',
                  color: Color(0xFF99CD60),
                ),
                SummaryCard(
                  title: 'กำลังตรวจสอบ / กำลังดำเนินการ',
                  value: '1',
                  color: Color(0xFFFECC52),
                ),
                SummaryCard(
                  title: 'จำนวนครุภัณฑ์ที่เสียหาย',
                  value: '2',
                  color: Color(0xFFE44F5A),
                ),
              ],
            ),

            const SizedBox(height: 60),

            MenuItem(
              imageUrl: 'https://cdn-icons-png.flaticon.com/512/9252/9252207.png',
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
              imageUrl: 'https://cdn-icons-png.flaticon.com/512/11873/11873385.png',
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
              imageUrl: 'https://cdn-icons-png.flaticon.com/256/4960/4960785.png',
              title: 'แจ้งปัญหา / ขัดข้อง',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportProblemScreen()),
                );
              },
            ),
            MenuItem(
              imageUrl: 'https://cdn-icons-png.flaticon.com/256/11726/11726423.png',
              title: 'ตรวจสอบอุปกรณ์',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InspectEquipmentScreen()),
                );
              },
            ),
          ],
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

// ===== SUMMARY CARD (ปรับใหม่) =====
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
      height: 120, // ⭐ กล่องสูงขึ้น
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24), // ⭐ มุมโค้งขึ้น
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 18, // ⭐ หัวข้อใหญ่ขึ้น
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter', // ⭐ ตัวเลขเด่น
              color: Colors.white,
              fontSize: 45,
              fontWeight: FontWeight.bold,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Image.network(
          imageUrl,
          width: 40,
          height: 40,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
