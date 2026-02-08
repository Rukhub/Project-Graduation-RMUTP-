import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../app_drawer.dart';
import '../widgets/report_card.dart';
import 'report_detail_screen.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  int? selectedStatusFilter;
  int? currentUserRole;
  String? currentUserId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      final userProfile = await FirebaseService().getUserProfileByUid(user.uid);
      if (mounted) {
        setState(() {
          currentUserRole = userProfile?.role ?? 0;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ประวัติการรายงาน'),
          backgroundColor: const Color(0xFF9A2C2C),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Icon(Icons.arrow_back, size: 16, color: Color(0xFF9A2C2C)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
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
        title: const Column(
          children: [
            Text(
              'ประวัติการรายงาน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Report History',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ทั้งหมด', null),
                  const SizedBox(width: 8),
                  _buildFilterChip('ซ่อมเสร็จ', 'completed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ซ่อมไม่ได้', 'cancelled'),
                ],
              ),
            ),
          ),

          // Report List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().getReportsHistoryStream(
                statusFilter: selectedStatusFilter,
                reporterId: currentUserRole == 1 ? null : currentUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'เกิดข้อผิดพลาด: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final rawReports = snapshot.data ?? [];
                final reports = selectedStatusFilter == null
                    ? rawReports.where((r) {
                        final s = FirebaseService.reportStatusToCode(
                          r['report_status'],
                        );
                        return s == 3 || s == 4;
                      }).toList()
                    : rawReports;

                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ไม่มีประวัติการรายงาน',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return ReportCard(
                      report: report,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportDetailScreen(
                              reportId: report['id'],
                              userRole: currentUserRole ?? 0,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final int? code = status == null
        ? null
        : FirebaseService.reportStatusToCode(status);
    final isSelected = selectedStatusFilter == code;
    Color chipColor;

    if (status == null) {
      chipColor = const Color(0xFF6B7280); // Grey for "All"
    } else if (code == 3) {
      chipColor = const Color(0xFF10B981); // Green
    } else if (code == 4) {
      chipColor = const Color(0xFFEF4444); // Red
    } else {
      chipColor = const Color(0xFF6B7280); // Grey
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedStatusFilter = selected ? code : null;
        });
      },
      selectedColor: chipColor,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
