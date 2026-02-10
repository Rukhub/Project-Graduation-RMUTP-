import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../app_drawer.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final int userRole;
  final bool readOnly;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.userRole,
    this.readOnly = false,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Map<String, dynamic>? reportData;
  String? reporterName;
  String? workerName;
  bool isLoading = true;
  bool isUpdating = false;

  void _openFullImage(String imageUrl) {
    final url = imageUrl.trim();
    if (url.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 280,
                        alignment: Alignment.center,
                        color: Colors.black,
                        child: const Text(
                          'ไม่สามารถโหลดรูปได้',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _repairAgainFromCancelled() async {
    if (isUpdating) return;
    if (reportData == null) return;

    final assetId = reportData!['asset_id']?.toString() ?? '';
    if (assetId.trim().isEmpty) return;

    final TextEditingController reasonController = TextEditingController();
    File? pickedImage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ซ่อมอีกครั้ง'),
              content: Builder(
                builder: (context) {
                  final screenW = MediaQuery.of(context).size.width;
                  final dialogW = screenW.isFinite
                      ? (screenW * 0.90).clamp(280.0, 420.0)
                      : 420.0;

                  return SizedBox(
                    width: dialogW,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('กรุณาระบุเหตุผลที่ต้องซ่อมอีกครั้ง:'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'เช่น เปลี่ยนอะไหล่/พบอาการใหม่/ทดสอบแล้วไม่ผ่าน...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final source =
                                      await showModalBottomSheet<ImageSource>(
                                        context: context,
                                        showDragHandle: true,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                        ),
                                        builder: (sheetContext) {
                                          return SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.photo_camera_outlined,
                                                  ),
                                                  title: const Text('ถ่ายรูป'),
                                                  onTap: () => Navigator.pop(
                                                    sheetContext,
                                                    ImageSource.camera,
                                                  ),
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons
                                                        .photo_library_outlined,
                                                  ),
                                                  title: const Text(
                                                    'เลือกรูปจากคลัง',
                                                  ),
                                                  onTap: () => Navigator.pop(
                                                    sheetContext,
                                                    ImageSource.gallery,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                  if (source == null) return;

                                  final picker = ImagePicker();
                                  final image = await picker.pickImage(
                                    source: source,
                                    imageQuality: 85,
                                  );
                                  if (image == null) return;
                                  if (!context.mounted) return;
                                  setDialogState(() {
                                    pickedImage = File(image.path);
                                  });
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('ไม่สามารถเลือกรูปได้: $e'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                pickedImage == null
                                    ? 'แนบรูปภาพ'
                                    : 'เปลี่ยนรูปภาพ',
                              ),
                            ),
                          ),
                          if (pickedImage != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                pickedImage!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 140,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    color: Colors.grey.shade200,
                                    child: const Text('ไม่สามารถแสดงรูปได้'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ยืนยัน'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกเหตุผล')));
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String? uploadedReportImageUrl;
      if (pickedImage != null) {
        uploadedReportImageUrl = await FirebaseService().uploadReportImage(
          pickedImage!,
          assetId,
        );
      }

      String workerFullname = workerName ?? '';
      if (workerFullname.trim().isEmpty) {
        final profile = await FirebaseService().getUserProfileByUid(
          currentUser.uid,
        );
        workerFullname = profile?.fullname ?? '';
      }
      if (workerFullname.trim().isEmpty) workerFullname = 'ไม่ระบุ';

      final newReportId = await FirebaseService().createRepairAgainReport(
        assetId: assetId,
        previousReportId: widget.reportId,
        reason: reason,
        workerId: currentUser.uid,
        workerName: workerFullname,
        reportImageUrl: uploadedReportImageUrl,
      );

      await FirebaseService().updateAsset(assetId, {
        'asset_status': 3,
        'repairer_id': currentUser.uid,
        'auditor_name': workerFullname,
        'condemned_at': FieldValue.delete(),
        'audited_at': DateTime.now(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReportDetailScreen(
            reportId: newReportId,
            userRole: widget.userRole,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    try {
      final data = await FirebaseService().getReportHistoryById(
        widget.reportId,
      );
      if (data != null && mounted) {
        setState(() {
          reportData = data;
        });
        await _loadUserNames();
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserNames() async {
    if (reportData == null) return;

    // Load reporter name
    final reporterId = reportData!['reporter_id'];
    if (reporterId != null) {
      final reporter = await FirebaseService().getUserProfileByUid(reporterId);
      if (mounted) {
        setState(() {
          reporterName = reporter?.fullname ?? 'ไม่ระบุ';
        });
      }
    }

    // Load worker name
    final workerId = reportData!['worker_id'];
    if (workerId != null) {
      final worker = await FirebaseService().getUserProfileByUid(workerId);
      if (mounted) {
        setState(() {
          workerName = worker?.fullname ?? 'ไม่ระบุ';
        });
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'ไม่ระบุ';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'ไม่ระบุ';
    }

    // Simple Thai date formatting without intl package
    const List<String> months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];

    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year + 543; // Buddhist calendar
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day $month $year $hour:$minute น.';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอรับเรื่อง';
      case 'repairing':
        return 'กำลังซ่อม';
      case 'completed':
        return 'ซ่อมเสร็จ';
      case 'cancelled':
        return 'ยกเลิก/ไม่สำเร็จ';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  Widget _buildTimelineSection() {
    final items = _buildTimelineItems();
    final int statusCode = FirebaseService.reportStatusToCode(
      reportData?['report_status'] ?? reportData?['status'],
    );
    final String statusLabel = switch (statusCode) {
      1 => 'รอรับเรื่อง',
      2 => 'กำลังซ่อม',
      3 => 'ซ่อมเสร็จ',
      4 => 'ซ่อมไม่ได้',
      _ => 'ไม่ทราบสถานะ',
    };
    final Color statusColor = switch (statusCode) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFFFF9800),
      3 => const Color(0xFF22C55E),
      4 => const Color(0xFFEF4444),
      _ => Colors.grey,
    };

    int firstUndoneIndex = items.indexWhere((e) => e['done'] != true);
    if (firstUndoneIndex < 0) {
      firstUndoneIndex = items.isNotEmpty ? items.length - 1 : 0;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ไทม์ไลน์',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...List.generate(items.length, (index) {
            final it = items[index];
            final title = (it['title'] ?? '').toString();
            final subtitle = (it['subtitle'] ?? '').toString();
            final note = it['note']?.toString();
            final time = it['time'];
            final Color color = (it['color'] as Color?) ?? Colors.grey;
            final IconData icon = (it['icon'] as IconData?) ?? Icons.circle;
            final bool done = it['done'] == true;
            final bool isLast = index == items.length - 1;

            final bool isActive = !done && index == firstUndoneIndex;
            final String stepChipText = done
                ? 'เสร็จแล้ว'
                : isActive
                ? 'กำลังดำเนินการ'
                : 'รอ';
            final Color stepChipColor = done
                ? color
                : isActive
                ? const Color(0xFF2563EB)
                : Colors.grey;

            final indicatorFill = done ? color : Colors.grey.shade300;
            final indicatorIconColor = done
                ? Colors.white
                : Colors.grey.shade600;
            final lineColor = done
                ? color.withValues(alpha: 0.35)
                : Colors.grey.shade300;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: indicatorFill,
                            shape: BoxShape.circle,
                            boxShadow: done
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            icon,
                            size: 14,
                            color: indicatorIconColor,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 56,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: lineColor,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: done
                            ? color.withValues(alpha: 0.08)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: done
                              ? color.withValues(alpha: 0.18)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: stepChipColor,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: stepChipColor.withValues(
                                        alpha: 0.30,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  stepChipText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (subtitle.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    time != null ? _formatTimestamp(time) : '-',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (note != null && note.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: TextStyle(
                                        color: Colors.grey.shade900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildTimelineItems() {
    final data = reportData;
    if (data == null) return [];

    final int statusCode = FirebaseService.reportStatusToCode(
      data['report_status'] ?? data['status'],
    );
    final reportedAt = data['reported_at'] ?? data['timestamp'];
    final startRepairAt = data['start_repair_at'];
    final finishedAt = data['finished_at'];
    final remarkReport =
        (data['report_remark'] ?? data['remark_report'] ?? data['issue'])
            ?.toString();
    final remarkFinished =
        (data['finished_remark'] ??
                data['remark_finished'] ??
                data['remark_completed'])
            ?.toString();
    final remarkBroken = data['remark_broken']?.toString();

    final reporter =
        reporterName ?? data['reporter_name']?.toString() ?? 'ไม่ระบุ';
    final worker = workerName ?? data['worker_name']?.toString() ?? 'ไม่ระบุ';

    bool hasReported = reportedAt != null;
    bool hasStart = startRepairAt != null;
    bool hasFinished = finishedAt != null;

    // Fallback by status when timestamps are missing
    if (!hasStart && (statusCode == 2 || statusCode == 3 || statusCode == 4)) {
      hasStart = true;
    }
    if (!hasFinished && (statusCode == 3 || statusCode == 4)) {
      hasFinished = true;
    }

    final items = <Map<String, dynamic>>[];
    items.add({
      'title': 'แจ้งซ่อม',
      'subtitle': reporter,
      'time': reportedAt,
      'note': remarkReport,
      'color': const Color(0xFFEF4444),
      'icon': Icons.warning_amber_rounded,
      'done': hasReported,
    });

    items.add({
      'title': 'รับงาน/เริ่มซ่อม',
      'subtitle': worker,
      'time': startRepairAt,
      'note': null,
      'color': const Color(0xFFFF9800),
      'icon': Icons.build_circle,
      'done': hasStart,
    });

    if (statusCode == 3) {
      items.add({
        'title': 'ซ่อมเสร็จ',
        'subtitle': worker,
        'time': finishedAt,
        'note': (remarkFinished != null && remarkFinished.trim().isNotEmpty)
            ? remarkFinished
            : null,
        'color': const Color(0xFF22C55E),
        'icon': Icons.check_circle,
        'done': hasFinished,
      });
    } else if (statusCode == 4) {
      items.add({
        'title': 'ซ่อมไม่ได้',
        'subtitle': worker,
        'time': finishedAt,
        'note': (remarkFinished != null && remarkFinished.trim().isNotEmpty)
            ? remarkFinished
            : (remarkBroken != null && remarkBroken.trim().isNotEmpty)
            ? remarkBroken
            : null,
        'color': const Color(0xFF6B7280),
        'icon': Icons.block,
        'done': hasFinished,
      });
    } else {
      items.add({
        'title': 'ปิดงาน',
        'subtitle': worker,
        'time': finishedAt,
        'note': null,
        'color': const Color(0xFF6B7280),
        'icon': Icons.flag,
        'done': hasFinished,
      });
    }

    return items;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'repairing':
        return const Color(0xFFFF9800);
      case 'completed':
        return const Color(0xFF22C55E);
      case 'cancelled':
        return const Color(0xFF6B7280);
      default:
        return Colors.grey;
    }
  }

  Future<void> _acceptRepair() async {
    if (isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันรับงานซ่อม'),
        content: const Text('คุณต้องการรับงานซ่อมนี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      String workerFullname = workerName ?? '';
      if (workerFullname.trim().isEmpty && currentUser != null) {
        final profile = await FirebaseService().getUserProfileByUid(
          currentUser.uid,
        );
        workerFullname = profile?.fullname ?? '';
      }
      await FirebaseService().updateReportStatus(
        widget.reportId,
        2,
        extraData: {
          'worker_id': currentUser!.uid,
          if (workerFullname.trim().isNotEmpty) 'worker_name': workerFullname,
          'start_repair_at': FieldValue.serverTimestamp(),
        },
      );
      await _loadReportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รับงานซ่อมเรียบร้อยแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<Map<String, String>> _getCurrentWorkerInfo() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String workerId = currentUser?.uid ?? 'unknown_uid';
    String workerFullname = workerName ?? '';

    if (workerFullname.trim().isEmpty && currentUser != null) {
      final profile = await FirebaseService().getUserProfileByUid(
        currentUser.uid,
      );
      workerFullname = profile?.fullname ?? '';
    }

    return {'worker_id': workerId, 'worker_name': workerFullname};
  }

  Future<void> _showRepairResultDialog({
    required String initialSelection,
  }) async {
    if (isUpdating) return;

    final TextEditingController completedNoteController =
        TextEditingController();
    final TextEditingController failedReasonController =
        TextEditingController();
    File? evidenceImage;

    String selected = initialSelection; // 'completed' | 'cancelled'

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isCompleted = selected == 'completed';
            final Color headerColor = isCompleted
                ? const Color(0xFF16A34A)
                : const Color(0xFFEF4444);
            final IconData headerIcon = isCompleted
                ? Icons.check_circle
                : Icons.cancel;
            final String headerTitle = isCompleted
                ? 'ปิดงานซ่อมบำรุง'
                : 'ปิดงานซ่อมบำรุง';
            final String headerSubtitle = isCompleted
                ? 'บันทึกผลการดำเนินการ'
                : 'บันทึกผลการดำเนินการ';

            Widget optionCard({
              required String value,
              required IconData icon,
              required String title,
              required String subtitle,
              required Color color,
            }) {
              final bool active = selected == value;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setDialogState(() => selected = value),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: active
                        ? color.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? color : Colors.grey.shade300,
                      width: active ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: active
                              ? color.withValues(alpha: 0.18)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: active ? color : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.black : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: active ? color : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: headerColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(headerIcon, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headerTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  headerSubtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เลือกผลการซ่อม',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            optionCard(
                              value: 'completed',
                              icon: Icons.check_circle,
                              title: 'ซ่อมเสร็จสิ้น',
                              subtitle: 'อุปกรณ์พร้อมใช้งานได้ปกติ',
                              color: const Color(0xFF16A34A),
                            ),
                            const SizedBox(height: 12),
                            optionCard(
                              value: 'cancelled',
                              icon: Icons.cancel,
                              title: 'ซ่อมไม่ได้',
                              subtitle: 'แนะนำจำหน่าย/แจ้งออก',
                              color: const Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 18),
                            if (selected == 'completed') ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.note,
                                    size: 16,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'หมายเหตุ (ถ้ามี)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: completedNoteController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText:
                                      'บันทึกหมายเหตุเพิ่มเติม (ถ้ามี)...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // ⭐ เพิ่มช่องรูปภาพหลังซ่อม
                              Row(
                                children: [
                                  Icon(
                                    Icons.photo_camera,
                                    size: 16,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'รูปภาพหลังซ่อม (ถ้ามี)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final source =
                                      await showModalBottomSheet<ImageSource>(
                                        context: context,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                        ),
                                        builder: (sheetContext) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Text(
                                                  'เลือกแหล่งที่มาของรูปภาพ',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.camera_alt,
                                                ),
                                                title: const Text('ถ่ายรูป'),
                                                onTap: () => Navigator.pop(
                                                  sheetContext,
                                                  ImageSource.camera,
                                                ),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.photo_library,
                                                ),
                                                title: const Text(
                                                  'เลือกจากแกลเลอรี่',
                                                ),
                                                onTap: () => Navigator.pop(
                                                  sheetContext,
                                                  ImageSource.gallery,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                      );
                                  if (source == null) return;
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? img = await picker.pickImage(
                                    source: source,
                                  );
                                  if (img == null) return;
                                  setDialogState(() {
                                    evidenceImage = File(img.path);
                                  });
                                },
                                child: Container(
                                  height: 140,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Center(
                                    child: evidenceImage == null
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_a_photo,
                                                size: 42,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'แตะเพื่อเพิ่มรูปภาพ',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Image.file(
                                              evidenceImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                            if (selected == 'cancelled') ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.description,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'เหตุผลที่ซ่อมไม่ได้*',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: failedReasonController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'ระบุสาเหตุที่ไม่สามารถซ่อมได้...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.photo_camera,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'หลักฐานภาพถ่าย*',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? img = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (img == null) return;
                                  setDialogState(() {
                                    evidenceImage = File(img.path);
                                  });
                                },
                                child: Container(
                                  height: 140,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Center(
                                    child: evidenceImage == null
                                        ? const Icon(
                                            Icons.add_a_photo,
                                            size: 42,
                                            color: Colors.grey,
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Image.file(
                                              evidenceImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('ยกเลิก'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: headerColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () {
                              if (selected == 'cancelled') {
                                if (failedReasonController.text
                                        .trim()
                                        .isEmpty ||
                                    evidenceImage == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'กรุณากรอกข้อมูลให้ครบถ้วน',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                              Navigator.pop(dialogContext, true);
                            },
                            child: const Text('ยืนยัน'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final workerInfo = await _getCurrentWorkerInfo();
      final String workerId = workerInfo['worker_id'] ?? 'unknown_uid';
      final String workerFullname = workerInfo['worker_name'] ?? '';

      if (selected == 'completed') {
        final assetId = reportData?['asset_id']?.toString();

        // ⭐ อัปโหลดรูปภาพหลังซ่อม (ถ้ามี)
        String finishedImageUrl = '';
        if (evidenceImage != null &&
            assetId != null &&
            assetId.trim().isNotEmpty) {
          final uploaded = await FirebaseService().uploadRepairImage(
            evidenceImage!,
            assetId,
          );
          finishedImageUrl = uploaded ?? '';
        }

        final updateData = <String, dynamic>{
          'finished_at': FieldValue.serverTimestamp(),
          'worker_id': workerId,
          if (workerFullname.trim().isNotEmpty) 'worker_name': workerFullname,
        };

        final note = completedNoteController.text.trim();
        if (note.isNotEmpty) {
          updateData['finished_remark'] = note;
        }

        // ⭐ บันทึก URL รูปภาพ
        if (finishedImageUrl.isNotEmpty) {
          updateData['finished_image_url'] = finishedImageUrl;
        }

        updateData['remark_broken'] = FieldValue.delete();
        updateData['broken_image_url'] = FieldValue.delete();
        updateData['remark_completed'] = FieldValue.delete();

        await FirebaseService().updateReportStatus(
          widget.reportId,
          3,
          extraData: updateData,
        );
      } else {
        final assetId = reportData?['asset_id']?.toString();
        if (assetId == null || assetId.trim().isEmpty) {
          throw Exception('Missing asset_id');
        }

        String brokenImageUrl = '';
        if (evidenceImage != null) {
          final uploaded = await FirebaseService().uploadRepairImage(
            evidenceImage!,
            assetId,
          );
          brokenImageUrl = uploaded ?? '';
        }

        await FirebaseService().updateReportStatus(
          widget.reportId,
          4,
          extraData: {
            'finished_remark': failedReasonController.text.trim(),
            'finished_image_url': brokenImageUrl,
            'finished_at': FieldValue.serverTimestamp(),
            'worker_id': workerId,
            if (workerFullname.trim().isNotEmpty) 'worker_name': workerFullname,
            'remark_broken': FieldValue.delete(),
            'broken_image_url': FieldValue.delete(),
            'remark_completed': FieldValue.delete(),
          },
        );
      }

      await _loadReportData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected == 'completed'
                  ? 'บันทึกซ่อมเสร็จเรียบร้อยแล้ว'
                  : 'บันทึกเรียบร้อยแล้ว',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> _completeRepair() async {
    await _showRepairResultDialog(initialSelection: 'completed');
  }

  Future<void> _markAsFailed() async {
    await _showRepairResultDialog(initialSelection: 'cancelled');
  }

  Future<void> _uploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final File imageFile = File(image.path);
      final assetId = reportData!['asset_id'].toString();
      final uploadedUrl = await FirebaseService().uploadReportImage(
        imageFile,
        assetId,
      );

      if (uploadedUrl != null) {
        await FirebaseService().updateReportStatus(
          widget.reportId,
          FirebaseService.reportStatusToCode(reportData!['report_status']),
          extraData: {'report_image_url': uploadedUrl},
        );
        await _loadReportData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('อัปโหลดรูปภาพเรียบร้อยแล้ว')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('กำลังโหลด...'),
          backgroundColor: const Color(0xFF9A2C2C),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (reportData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ไม่พบข้อมูล'),
          backgroundColor: const Color(0xFF9A2C2C),
        ),
        body: const Center(child: Text('ไม่พบข้อมูลรายการแจ้งซ่อมนี้')),
      );
    }

    final int statusCode = FirebaseService.reportStatusToCode(
      reportData!['report_status'] ?? reportData!['status'],
    );
    final String status = statusCode == 1
        ? 'pending'
        : statusCode == 2
        ? 'repairing'
        : statusCode == 3
        ? 'completed'
        : 'cancelled';
    final assetId = reportData!['asset_id']?.toString() ?? 'ไม่ระบุรหัส';
    final issue =
        (reportData!['report_remark'] ??
                reportData!['remark_report'] ??
                reportData!['issue'])
            ?.toString() ??
        'ไม่มีรายละเอียด';
    final reportImageUrl = reportData!['report_image_url']?.toString() ?? '';
    final finishedImageUrl =
        reportData!['finished_image_url']?.toString() ?? '';
    final brokenImageUrl = reportData!['broken_image_url']?.toString() ?? '';
    final reportedAt = reportData!['reported_at'];
    final startRepairAt = reportData!['start_repair_at'];
    final finishedAt = reportData!['finished_at'];
    final remarkBroken = reportData!['remark_broken']?.toString() ?? '';
    final remarkFinished =
        (reportData!['finished_remark'] ??
                reportData!['remark_finished'] ??
                reportData!['remark_completed'])
            ?.toString() ??
        '';

    final String cancelledNote = remarkFinished.trim().isNotEmpty
        ? remarkFinished
        : remarkBroken;
    final String cancelledImageUrl = finishedImageUrl.trim().isNotEmpty
        ? finishedImageUrl
        : brokenImageUrl;

    final isAdmin = widget.userRole == 1;
    final canEdit = isAdmin && !widget.readOnly;

    final String assignedWorkerId = (reportData!['worker_id'] ?? '')
        .toString()
        .trim();
    final String assignedWorkerName =
        (reportData!['worker_name'] ?? workerName ?? '').toString().trim();
    final String currentUid =
        FirebaseAuth.instance.currentUser?.uid.toString().trim() ?? '';
    final bool canFinishRepair =
        canEdit &&
        status == 'repairing' &&
        (assignedWorkerId.isEmpty || assignedWorkerId == currentUid);

    final String assignedWorkerDisplay = assignedWorkerName.isNotEmpty
        ? assignedWorkerName
        : (assignedWorkerId.isNotEmpty ? assignedWorkerId : 'ไม่ระบุ');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
        centerTitle: true,
        title: Column(
          children: [
            Text(
              assetId,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(status),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildTimelineSection(),
              const SizedBox(height: 16),

              // Problem Section
              _buildSection(
                title: 'ปัญหาที่แจ้ง',
                icon: Icons.report_problem,
                color: const Color(0xFFEF4444),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.person,
                      'แจ้งโดย',
                      reporterName ?? 'กำลังโหลด...',
                      iconColor: const Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.description,
                      'ปัญหาที่แจ้ง',
                      issue,
                      iconColor: const Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.access_time,
                      'เวลาที่แจ้ง',
                      _formatTimestamp(reportedAt),
                      iconColor: const Color(0xFFEF4444),
                    ),
                    if (reportImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _openFullImage(reportImageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            reportImageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                alignment: Alignment.center,
                                child: const Text('ไม่สามารถโหลดรูปได้'),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (status == 'completed') ...[
                _buildSection(
                  title: 'ซ่อมเสร็จ',
                  icon: Icons.check_circle,
                  color: const Color(0xFF22C55E),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.person,
                        'บันทึกโดย',
                        workerName ?? 'ไม่ระบุ',
                        iconColor: const Color(0xFF22C55E),
                      ),
                      const SizedBox(height: 8),
                      if (remarkFinished.trim().isNotEmpty) ...[
                        _buildInfoRow(
                          Icons.description,
                          'หมายเหตุ',
                          remarkFinished,
                          iconColor: const Color(0xFF22C55E),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildInfoRow(
                        Icons.access_time,
                        'เวลาที่ซ่อมเสร็จ',
                        _formatTimestamp(finishedAt),
                        iconColor: const Color(0xFF22C55E),
                      ),
                      if (finishedImageUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.photo_camera,
                              size: 16,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'รูปภาพหลังซ่อม',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _openFullImage(finishedImageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              finishedImageUrl,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  alignment: Alignment.center,
                                  child: const Text('ไม่สามารถโหลดรูปได้'),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (status == 'cancelled') ...[
                const SizedBox(height: 16),
                _buildSection(
                  title: 'ซ่อมไม่ได้',
                  icon: Icons.cancel,
                  color: const Color(0xFF6B7280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.person,
                        'บันทึกโดย',
                        workerName ?? 'ไม่ระบุ',
                      ),
                      const SizedBox(height: 8),
                      if (cancelledNote.trim().isNotEmpty) ...[
                        _buildInfoRow(
                          Icons.description,
                          'เหตุผลที่ซ่อมไม่ได้',
                          cancelledNote,
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildInfoRow(
                        Icons.access_time,
                        'เวลาที่ซ่อมไม่ได้',
                        _formatTimestamp(finishedAt),
                      ),
                      if (cancelledImageUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.photo_camera,
                              size: 16,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'หลักฐานซ่อมไม่ได้',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _openFullImage(cancelledImageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              cancelledImageUrl,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  alignment: Alignment.center,
                                  child: const Text('ไม่สามารถโหลดรูปได้'),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Repair Section (if report status is repairing/completed/cancelled)
              if (status != 'pending') ...[
                _buildSection(
                  title: 'ข้อมูลการซ่อม',
                  icon: Icons.build,
                  color: const Color(0xFFFF9800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.person,
                        'ช่างผู้รับผิดชอบ',
                        workerName ?? 'กำลังโหลด...',
                        iconColor: const Color(0xFFFF9800),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.play_arrow,
                        'เริ่มซ่อมเมื่อ',
                        _formatTimestamp(startRepairAt),
                        iconColor: const Color(0xFFFF9800),
                      ),
                      if (status == 'completed' || status == 'cancelled') ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.check_circle,
                          'เสร็จสิ้นเมื่อ',
                          _formatTimestamp(finishedAt),
                          iconColor: const Color(0xFFFF9800),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Admin Action Buttons
              if (canEdit &&
                  (status == 'pending' || status == 'repairing')) ...[
                const SizedBox(height: 8),
                if (status == 'pending') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUpdating ? null : _acceptRepair,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'รับงานซ่อม',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 1,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
                if (status == 'repairing') ...[
                  if (!canFinishRepair) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'งานนี้ถูกรับผิดชอบโดย "$assignedWorkerDisplay" คนอื่นไม่สามารถปิดงานซ่อมได้',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (isUpdating || !canFinishRepair)
                          ? null
                          : _completeRepair,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        'ซ่อมเสร็จ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF16A34A),
                        side: const BorderSide(
                          color: Color(0xFF16A34A),
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (isUpdating || !canFinishRepair)
                          ? null
                          : _markAsFailed,
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text(
                        'ซ่อมไม่ได้',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(
                          color: Color(0xFFEF4444),
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ],

              if (canEdit && status == 'cancelled') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isUpdating ? null : _repairAgainFromCancelled,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text(
                      'ซ่อมอีกครั้ง',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),

          // Loading Overlay
          if (isUpdating)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
