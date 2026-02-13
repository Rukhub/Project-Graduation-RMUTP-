import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const ReportCard({super.key, required this.report, required this.onTap});

  int _reportStatusToCode(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty || s == 'null') return 1;
    if (s == 'pending') return 1;
    if (s == 'repairing') return 2;
    if (s == 'completed') return 3;
    if (s == 'cancelled') return 4;
    return int.tryParse(s) ?? 1;
  }

  String _getStatusText(int statusCode) {
    switch (statusCode) {
      case 1:
        return 'รอรับงาน';
      case 2:
        return 'กำลังซ่อม';
      case 3:
        return 'ซ่อมเสร็จ';
      case 4:
        return 'ซ่อมไม่ได้';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  Color _getStatusColor(int statusCode) {
    switch (statusCode) {
      case 1:
        return const Color(0xFFEF4444); // Red
      case 2:
        return const Color(0xFFFF9800); // Orange
      case 3:
        return const Color(0xFF10B981); // Green
      case 4:
        return const Color(0xFF6B7280); // Grey
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(int statusCode) {
    switch (statusCode) {
      case 1:
        return Icons.notification_important;
      case 2:
        return Icons.build;
      case 3:
        return Icons.check_circle;
      case 4:
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatReportDocId(String rawId) {
    // Example: KUYKRIS_20260207-012452-140 -> KUYKRIS_20260207-012452
    return rawId.replaceFirst(RegExp(r'-\d{3}$'), '');
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
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year + 543; // Buddhist calendar
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day $month $year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final String assetId = report['asset_id']?.toString() ?? 'ไม่ระบุรหัส';
    final String? linkedReportId = report['report_id']?.toString();
    final bool isRepairAgain =
        linkedReportId != null && linkedReportId.trim().isNotEmpty;

    final String reporter =
        report['reporter_name']?.toString().trim().isNotEmpty == true
        ? report['reporter_name']?.toString() ?? ''
        : (report['reporter_id']?.toString() ?? '');

    final String issue = isRepairAgain
        ? ((report['report_remark'] ?? report['remark_report'])?.toString() ??
              report['issue']?.toString() ??
              'ไม่มีรายละเอียด')
        : ((report['report_remark'] ?? report['remark_report'])?.toString() ??
              report['issue']?.toString() ??
              'ไม่มีรายละเอียด');
    final int statusCode = _reportStatusToCode(
      report['report_status'] ?? report['status'],
    );

    final String worker =
        report['worker_name']?.toString().trim().isNotEmpty == true
        ? report['worker_name']?.toString() ?? ''
        : (report['worker_id']?.toString() ?? '');

    final String cancelledNote =
        (report['finished_remark'] ??
                report['remark_finished'] ??
                report['remark_completed'] ??
                report['remark_broken'])
            ?.toString() ??
        '';
    final String remarkText =
        (statusCode == 4 && cancelledNote.trim().isNotEmpty)
        ? cancelledNote
        : issue;

    final String imageUrl = isRepairAgain
        ? ''
        : (report['report_image_url']?.toString() ?? '');
    final dynamic reportedAt = report['reported_at'];
    final String? reportIdRaw = report['id']?.toString();
    final String? reportIdDisplay =
        (reportIdRaw != null && reportIdRaw.isNotEmpty)
        ? _formatReportDocId(reportIdRaw)
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStatusColor(statusCode).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(statusCode).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStatusIcon(statusCode),
                color: _getStatusColor(statusCode),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),

            // Middle: Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asset ID
                  Text(
                    assetId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (reporter.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reporter,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (statusCode == 4 && worker.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.handyman_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'ผู้ดำเนินการ: $worker',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'หมายเหตุ: $remarkText',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Timestamp
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(reportedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  if (statusCode == 2 && worker.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.handyman_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'กำลังซ่อมโดย: $worker',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (isRepairAgain) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'ซ่อมอีกครั้ง',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right: Status Badge + Image Indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statusCode),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(statusCode),
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(statusCode),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Image Indicator
                if (imageUrl.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
