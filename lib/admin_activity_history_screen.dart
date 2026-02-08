import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'app_drawer.dart';
import 'equipment_detail_screen.dart';
import 'services/firebase_service.dart';
import 'screens/report_detail_screen.dart';

class AdminActivityHistoryScreen extends StatefulWidget {
  const AdminActivityHistoryScreen({super.key});

  @override
  State<AdminActivityHistoryScreen> createState() =>
      _AdminActivityHistoryScreenState();
}

class _AdminActivityHistoryScreenState extends State<AdminActivityHistoryScreen>
    with SingleTickerProviderStateMixin {
  // ⭐ Add Mixin

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> allActivities =
      []; // Rename from checkLogs to avoid confusion
  bool isLoading = true;
  String? errorMessage;
  late TabController _tabController; // ⭐ TabController

  // สถิติ
  int totalInspections = 0;
  int reportPendingCount = 0;
  int reportRepairingCount = 0;
  int reportCancelledCount = 0;
  int normalCount = 0;

  bool _isMigratingAudits = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // ⭐ Init TabController
    _loadActivityHistory();
  }

  Widget _buildTicketProcessPreview(Map<String, dynamic> item) {
    final reportedAt = item['reported_at'] ?? item['timestamp'];
    final startRepairAt = item['start_repair_at'];
    final finishedAt = item['finished_at'];
    final status = item['report_status'] ?? item['status'];

    bool hasReported = reportedAt != null;
    bool hasStart = startRepairAt != null;
    bool hasFinished = finishedAt != null;

    // Fallback by status when timestamps are missing
    final s = FirebaseService.reportStatusToCode(status);
    if (!hasStart && (s == 2 || s == 3 || s == 4)) {
      hasStart = true;
    }
    if (!hasFinished && (s == 3 || s == 4)) {
      hasFinished = true;
    }

    Widget step({
      required String label,
      required bool done,
      required Color color,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: done ? color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: done ? Colors.grey.shade800 : Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    Widget divider() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 18,
        height: 1,
        color: Colors.grey.shade300,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          step(
            label: 'แจ้งซ่อม',
            done: hasReported,
            color: const Color(0xFFEF4444),
          ),
          divider(),
          step(
            label: 'เริ่มซ่อม',
            done: hasStart,
            color: const Color(0xFFFF9800),
          ),
          divider(),
          step(
            label: 'ปิดงาน',
            done: hasFinished,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Future<void> _migrateAuditsHistoryDocIds() async {
    if (_isMigratingAudits) return;

    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'จัดระเบียบชื่อเอกสาร (audits_history)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'ระบบจะสร้างเอกสารใหม่ที่มี Document ID อ่านง่าย แล้วลบเอกสารเก่าที่เป็นชื่อสุ่ม\n\nแนะนำให้ทำครั้งเดียวเท่านั้น',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2C2C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ทำเลย'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isMigratingAudits = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF9A2C2C)),
        );
      },
    );

    try {
      int migratedCount = 0;
      bool deletedOld = true;
      try {
        migratedCount = await FirebaseService().migrateAuditsHistoryDocIds(
          deleteOld: true,
        );
      } catch (e) {
        deletedOld = false;
        migratedCount = await FirebaseService().migrateAuditsHistoryDocIds(
          deleteOld: false,
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // close progress

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deletedOld
                ? 'จัดระเบียบสำเร็จ: $migratedCount รายการ'
                : 'จัดระเบียบสำเร็จ: $migratedCount รายการ (ไม่สามารถลบเอกสารเก่าได้)',
          ),
          backgroundColor: const Color(0xFF99CD60),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadActivityHistory();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close progress
      messenger.showSnackBar(
        SnackBar(
          content: Text('จัดระเบียบไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isMigratingAudits = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose(); // ⭐ Dispose
    super.dispose();
  }

  Future<void> _loadActivityHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Ticket-based history (reports_history) only
      final reports = await FirebaseService().getAllReports();
      debugPrint('📢 Reports found in Firestore: ${reports.length}');

      final processedReports = reports.map((report) {
        final statusCode = FirebaseService.reportStatusToCode(
          report['report_status'] ?? report['status'],
        );

        String category = 'report_pending';
        if (statusCode == 2) {
          category = 'report_repairing';
        } else if (statusCode == 3) {
          category = 'normal';
        } else if (statusCode == 4) {
          category = 'report_cancelled';
        }

        String statusStr = 'แจ้งซ่อม';
        if (statusCode == 2) {
          statusStr = 'กำลังซ่อม';
        } else if (statusCode == 3) {
          statusStr = 'ซ่อมเสร็จ';
        } else if (statusCode == 4) {
          statusStr = 'ซ่อมไม่ได้';
        }

        final dateField =
            report['finished_at'] ??
            report['start_repair_at'] ??
            report['reported_at'] ??
            report['timestamp'];

        final note =
            (report['report_remark'] ??
                    report['remark_report'] ??
                    report['issue_detail'] ??
                    report['issue'])
                ?.toString();

        return {
          ...report,
          'activity_type': 'report',
          'category': category,
          'report_status': statusCode,
          'date': dateField,
          'status': statusStr,
          'note': note,
        };
      }).toList();

      // Reports only
      List<Map<String, dynamic>> combined = [...processedReports];
      debugPrint(
        '🔁 Total combined activities: ${combined.length}',
      ); // ⭐ Debug 4

      // ✅ This screen is "closed history" only (show only ซ่อมเสร็จ + ซ่อมไม่ได้)
      combined = combined.where((item) {
        final cat = item['category']?.toString() ?? '';
        return cat == 'normal' || cat == 'report_cancelled';
      }).toList();

      // ⭐ DEBUG: Check keys in first item
      if (combined.isNotEmpty) {
        debugPrint('🔍 First Item Keys: ${combined.first.keys.toList()}');
        debugPrint('🔍 First Item Data: ${combined.first}');
      }

      // เรียงลำดับ
      combined.sort((a, b) {
        DateTime dateA = DateTime(2000);
        DateTime dateB = DateTime(2000);

        if (a['date'] is Timestamp) {
          dateA = (a['date'] as Timestamp).toDate();
        } else if (a['date'] != null) {
          dateA = DateTime.tryParse(a['date'].toString()) ?? DateTime(2000);
        }

        if (b['date'] is Timestamp) {
          dateB = (b['date'] as Timestamp).toDate();
        } else if (b['date'] != null) {
          dateB = DateTime.tryParse(b['date'].toString()) ?? DateTime(2000);
        }

        return dateB.compareTo(dateA);
      });

      // คำนวณสถิติ
      int pending = 0;
      int repairing = 0;
      int cancelled = 0;
      int normal = 0;

      for (final item in combined) {
        final cat = item['category']?.toString() ?? '';
        if (cat == 'report_repairing') {
          repairing++;
        } else if (cat == 'report_cancelled') {
          cancelled++;
        } else if (cat == 'report_pending') {
          pending++;
        } else if (cat == 'normal') {
          normal++;
        }
      }

      if (mounted) {
        setState(() {
          allActivities = combined;
          totalInspections = combined.length;
          reportPendingCount = pending;
          reportRepairingCount = repairing;
          reportCancelledCount = cancelled;
          normalCount = normal;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $e';
        });
      }
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '-';
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else {
        date = DateTime.parse(dateValue.toString());
      }
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return dateValue.toString();
    }
  }

  Map<String, dynamic> _getStatusInfo(String? status) {
    if (status == null || status.isEmpty || status == 'null') {
      return {
        'label': 'ไม่ระบุสถานะ',
        'color': Colors.grey,
        'icon': Icons.help_outline,
        'bgColor': Colors.grey.shade100,
      };
    }
    switch (status) {
      case 'แจ้งซ่อม':
        return {
          'label': 'แจ้งซ่อม',
          'color': Color(0xFFF44336),
          'icon': Icons.warning_amber_rounded,
          'bgColor': Color(0xFFFFEBEE),
        };
      case 'กำลังซ่อม':
        return {
          'label': 'กำลังซ่อม',
          'color': Color(0xFFFF9800),
          'icon': Icons.build_circle,
          'bgColor': Color(0xFFFFF3E0),
        };
      case 'ซ่อมไม่ได้':
        return {
          'label': 'ซ่อมไม่ได้',
          'color': Color(0xFF6B7280),
          'icon': Icons.block,
          'bgColor': Color(0xFFF3F4F6),
        };
      case 'ซ่อมเสร็จ':
      case 'ปกติ':
      case 'Normal':
        return {
          'label': 'ซ่อมเสร็จ',
          'color': Color(0xFF4CAF50),
          'icon': Icons.check_circle,
          'bgColor': Color(0xFFE8F5E9),
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info_outline,
          'bgColor': Colors.grey.shade100,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: const AppDrawer(),
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF9A2C2C)),
            )
          : errorMessage != null
          ? _buildErrorState()
          : allActivities.isEmpty
          ? _buildEmptyState()
          : Column(
              // ⭐ Structure Change
              children: [
                Expanded(
                  child: TabBarView(
                    // ⭐ TabBarView
                    controller: _tabController,
                    children: [
                      // Tab 1: ทั้งหมด (ซ่อมเสร็จ + ซ่อมไม่ได้)
                      _buildActivityList(
                        (item) =>
                            item['category'] == 'normal' ||
                            item['category'] == 'report_cancelled',
                        'รายการทั้งหมด',
                      ),

                      // Tab 2: ซ่อมไม่ได้ (cancelled)
                      _buildActivityList(
                        (item) => item['category'] == 'report_cancelled',
                        'รายการซ่อมไม่ได้',
                      ),

                      // Tab 3: ซ่อมเสร็จ (completed/normal)
                      _buildActivityList(
                        (item) => item['category'] == 'normal',
                        'รายการซ่อมเสร็จ',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(
        0xFF9A2C2C,
      ), // ⭐ Solid Brand Color (No Gradient)
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'เมนู',
          icon: const Icon(Icons.menu, color: Colors.white, size: 28),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        IconButton(
          tooltip: 'จัดระเบียบ Doc ID (audits_history)',
          onPressed: _isMigratingAudits ? null : _migrateAuditsHistoryDocIds,
          icon: const Icon(Icons.auto_fix_high),
        ),
      ],
      title: const Text(
        'ประวัติการซ่อม',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3.5,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ), // Reduce size for 3 tabs
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'ทั้งหมด'),
          Tab(text: 'ซ่อมไม่ได้'),
          Tab(text: 'ซ่อมเสร็จ'),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildBlockStatItem(
                label: 'ทั้งหมด',
                count: totalInspections,
                color: Colors.blue.shade700,
                filled: false,
              ),
            ),
            Expanded(
              child: _buildBlockStatItem(
                label: 'ซ่อมไม่ได้',
                count: reportCancelledCount,
                color: const Color(0xFF6B7280),
              ),
            ),
            Expanded(
              child: _buildBlockStatItem(
                label: 'ซ่อมเสร็จ',
                count: normalCount,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockStatItem({
    required String label,
    required int count,
    required Color color,
    bool filled = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildContainerSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ... _buildSummaryItem can remain or use the new one ...
  Widget _buildActivityList(
    bool Function(Map<String, dynamic>) filter,
    String emptyTitle,
  ) {
    // Filter data using the passed function
    final list = allActivities.where(filter).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              'ไม่มีข้อมูล$emptyTitle',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF9A2C2C),
      onRefresh: _loadActivityHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildTimelineCard(list[index]),
      ),
    );
  }

  // Helper for Summary Items
  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ...

  Widget _buildTimelineCard(Map<String, dynamic> item) {
    final activityType = item['activity_type'] ?? 'inspection';
    final isReport = activityType == 'report';
    final status = item['status']?.toString() ?? 'ไม่ระบุ';
    final statusInfo = _getStatusInfo(status);

    final category = item['category']?.toString() ?? '';
    final bool isCancelled = category == 'report_cancelled';
    final bool isCompleted = category == 'normal';

    final assetId = item['asset_id']?.toString() ?? '-';
    final title =
        item['brand_model'] ?? item['asset_type'] ?? item['type'] ?? assetId;
    // ⭐ Prioritize Room Name
    final roomName = item['room_name'] ?? '';
    final floor = item['floor']?.toString() ?? '';
    String locationText = roomName.isNotEmpty
        ? '$roomName ${floor.isNotEmpty ? "($floor)" : ""}'
        : (item['location'] ?? 'ไม่ระบุสถานที่');

    // Subtitle now shows Room Name prominently if available, else Type/ID
    final subTitle = locationText != 'ไม่ระบุสถานที่'
        ? locationText
        : (item['asset_type'] ?? item['type'] ?? '');

    final date = _formatDate(item['date']);

    final reportedIssue =
        (item['report_remark'] ??
                item['remark_report'] ??
                item['issue_detail'] ??
                item['issue'] ??
                item['note'])
            ?.toString()
            .trim();
    final failedReason =
        (item['finished_remark'] ??
                item['remark_finished'] ??
                item['remark_broken'] ??
                item['failed_reason'])
            ?.toString()
            .trim();
    final completedNote =
        (item['finished_remark'] ??
                item['remark_finished'] ??
                item['remark_completed'] ??
                item['completed_note'])
            ?.toString()
            .trim();

    final String? note = isCancelled
        ? failedReason
        : (isCompleted ? completedNote : (reportedIssue ?? ''));

    final reporterName = (item['reporter_name'] ?? '').toString().trim();
    final workerName = (item['worker_name'] ?? '').toString().trim();
    final actorName = isReport
        ? (reporterName.isNotEmpty ? reporterName : 'ไม่ระบุผู้แจ้ง')
        : (item['auditor_name'] ?? item['inspectorName'] ?? 'ไม่ระบุผู้ตรวจ');

    String _firstOrEmpty(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return '';
      return s.contains(',') ? s.split(',').first.trim() : s;
    }

    final reportImageUrl = _firstOrEmpty(
      item['report_image_url'] ?? item['report_image'],
    );
    final brokenEvidenceUrl = _firstOrEmpty(item['broken_image_url']);
    final finishedEvidenceUrl = _firstOrEmpty(item['finished_image_url']);

    String? imageUrl;
    if (isCancelled && finishedEvidenceUrl.isNotEmpty) {
      imageUrl = finishedEvidenceUrl;
    } else if (isCancelled && brokenEvidenceUrl.isNotEmpty) {
      imageUrl = brokenEvidenceUrl;
    } else if (isCompleted && finishedEvidenceUrl.isNotEmpty) {
      imageUrl = finishedEvidenceUrl;
    } else if (reportImageUrl.isNotEmpty) {
      imageUrl = reportImageUrl;
    } else if (_firstOrEmpty(item['images']).isNotEmpty) {
      imageUrl = _firstOrEmpty(item['images']);
    }

    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl =
          '${ApiService.baseUrl.replaceAll('/api', '')}/uploads/$imageUrl';
    }

    // ⭐ กำหนดสีตามสถานะ (สำหรับ Border และ Background)
    Color cardBorderColor;
    Color cardBgColor;
    final color = statusInfo['color'] as Color;
    cardBorderColor = color;
    cardBgColor = (statusInfo['bgColor'] as Color);

    return GestureDetector(
      onTap: () {
        if (isReport) {
          final reportId = item['id']?.toString() ?? '';
          if (reportId.trim().isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDetailScreen(
                reportId: reportId,
                userRole: 1,
                readOnly: true,
              ),
            ),
          );
          return;
        }

        if (item['asset_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EquipmentDetailScreen(
                equipment: {
                  'asset_id': assetId,
                  'type': item['asset_type'] ?? item['type'],
                  'status': status,
                  'room_name': roomName,
                  'floor': floor,
                  'location_id': item['location_id'] ?? 0,
                  'asset_image_url': imageUrl,
                  'created_name': item['created_name'],
                  'reporter_name': item['reporter_name'],
                  'report_reason': item['issue_detail'] ?? item['note'],
                  'brand_model': item['brand_model'],
                },
                roomName: roomName.isNotEmpty
                    ? (floor.isNotEmpty
                          ? '$roomName (${floor.startsWith('ชั้น') ? floor : 'ชั้น $floor'})'
                          : roomName)
                    : 'ไม่ระบุห้อง',
                autoOpenCheckDialog: false, //
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cardBorderColor.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: cardBorderColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: cardBorderColor,
                  width: 5,
                ), // ⭐ แถบสีซ้าย
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Header with status color hint
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isReport
                              ? Icons.warning_amber_rounded
                              : statusInfo['icon'],
                          size: 16,
                          color: cardBorderColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusInfo['label'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cardBorderColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Top Row: Image + Text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      SizedBox(
                        width: 65,
                        height: 65,
                        child: Stack(
                          children: [
                            Container(
                              width: 65,
                              height: 65,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade100,
                                border: Border.all(
                                  color: cardBorderColor.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                image: (imageUrl != null && imageUrl.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (imageUrl == null || imageUrl.isEmpty)
                                  ? Icon(
                                      isReport
                                          ? Icons.broken_image_rounded
                                          : Icons.inventory_2_rounded,
                                      color: cardBorderColor.withValues(
                                        alpha: 0.5,
                                      ),
                                      size: 30,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (isReport) _buildTicketProcessPreview(item),
                            if (isReport) ...[
                              const SizedBox(height: 8),
                              if (reporterName.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: const Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        reporterName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: const Color.fromARGB(
                                            255,
                                            0,
                                            0,
                                            0,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              Row(
                                children: [
                                  Icon(
                                    Icons.report_problem_outlined,
                                    size: 14,
                                    color: const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      (reportedIssue == null ||
                                              reportedIssue.isEmpty ||
                                              reportedIssue == 'null')
                                          ? '-'
                                          : 'หมายเหตุ: $reportedIssue',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (workerName.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.build_circle_outlined,
                                      size: 14,
                                      color: const Color(0xFFFF9800),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        workerName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: const Color.fromARGB(
                                            255,
                                            0,
                                            0,
                                            0,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (isCancelled &&
                                  failedReason != null &&
                                  failedReason.isNotEmpty &&
                                  failedReason != 'null') ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'หมายเหตุ: $failedReason',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (isCompleted &&
                                  completedNote != null &&
                                  completedNote.isNotEmpty &&
                                  completedNote != 'null') ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 14,
                                      color: Color(0xFF22C55E),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'หมายเหตุ: $completedNote',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                            const SizedBox(height: 6),
                            Text(
                              subTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bottom Row: Status + Actor/Note
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusInfo['bgColor'],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusInfo['icon'],
                                size: 12,
                                color: statusInfo['color'],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusInfo['label'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusInfo['color'],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Actor Name
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              actorName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                            ),
                            // If note exists, show small indicator
                            if (note != null &&
                                note.isNotEmpty &&
                                note != 'null') ...[
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                width: 1,
                                height: 12,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.comment_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(errorMessage ?? 'Error'));
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('ไม่มีประวัติการซ่อม'));
  }
}
