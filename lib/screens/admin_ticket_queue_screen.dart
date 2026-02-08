import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_drawer.dart';
import '../services/firebase_service.dart';
import '../widgets/report_card.dart';
import 'report_detail_screen.dart';

class AdminTicketQueueScreen extends StatelessWidget {
  const AdminTicketQueueScreen({super.key});

  Widget _buildList(BuildContext context, String? statusFilter) {
    final int? statusCodeFilter = statusFilter == null
        ? null
        : FirebaseService.reportStatusToCode(statusFilter);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().getReportsHistoryStream(
        statusFilter: statusCodeFilter,
        reporterId: null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'เกิดข้อผิดพลาด: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final reports = (snapshot.data ?? []).toList();
        DateTime toDate(dynamic v) {
          try {
            if (v is DateTime) return v;
            if (v is Timestamp) return v.toDate();
            if (v != null && v.toString().isNotEmpty) {
              return DateTime.tryParse(v.toString()) ?? DateTime(2000);
            }
          } catch (_) {}
          return DateTime(2000);
        }

        reports.sort((a, b) {
          final da = toDate(a['reported_at'] ?? a['timestamp'] ?? a['date']);
          final db = toDate(b['reported_at'] ?? b['timestamp'] ?? b['date']);
          return db.compareTo(da);
        });
        if (reports.isEmpty) {
          return Center(
            child: Text(
              statusCodeFilter == 2
                  ? 'ไม่มีรายการกำลังซ่อม'
                  : 'ไม่มีรายการรอรับงาน',
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
                final reportId = report['id']?.toString() ?? '';
                if (reportId.trim().isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportDetailScreen(
                      reportId: reportId,
                      userRole: 1,
                      readOnly: false,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9A2C2C),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Icon(Icons.arrow_back, size: 16, color: Color(0xFF9A2C2C)),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'คิวงานแจ้งปัญหา',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'รอรับงาน'),
              Tab(text: 'กำลังซ่อม'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(context, 'pending'),
            _buildList(context, 'repairing'),
          ],
        ),
      ),
    );
  }
}
