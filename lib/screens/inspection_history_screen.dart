import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class InspectionHistoryScreen extends StatefulWidget {
  const InspectionHistoryScreen({super.key});

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends State<InspectionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';

  String _assetTypeFilter = 'all';
  List<String> _assetTypes = [];
  bool _isLoadingAssetTypes = false;
  final Map<String, String> _assetTypeById = {};
  final Map<String, String> _categoryNameById = {};

  final Map<String, String> _reportImageByAssetId = {};
  final Map<String, String> _reportRemarkByAssetId = {};

  bool _fallbackOrderByDocId = false;

  DateTimeRange? _dateRange;
  bool get _hasDateFilter => _dateRange != null;

  static const int _pageSize = 30;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next == _query) return;
      setState(() {
        _query = next;
      });
    });
    _loadAssetTypes();
    _loadFirstPage();
  }

  Future<String?> _getReportRemarkForAsset(String assetId) async {
    final trimmed = assetId.trim();
    if (trimmed.isEmpty) return null;
    final cached = _reportRemarkByAssetId[trimmed];
    if (cached != null) return cached;

    try {
      final reports = await FirebaseService().getReports(trimmed);
      if (reports.isEmpty) return null;

      String? pickRemarkFrom(Map<String, dynamic> r) {
        final candidates = [
          r['finished_remark'],
          r['report_remark'],
          r['remark_broken'],
          r['remark_finished'],
          r['remark_report'],
          r['audit_note'],
          r['note'],
          r['remark'],
        ];
        for (final c in candidates) {
          final s = c?.toString().trim();
          if (s != null && s.isNotEmpty) return s;
        }
        return null;
      }

      for (final r in reports) {
        final remark = pickRemarkFrom(r);
        if (remark != null && remark.isNotEmpty) {
          _reportRemarkByAssetId[trimmed] = remark;
          return remark;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getReportImageForAsset(String assetId) async {
    final trimmed = assetId.trim();
    if (trimmed.isEmpty) return null;
    final cached = _reportImageByAssetId[trimmed];
    if (cached != null) return cached;

    try {
      final reports = await FirebaseService().getReports(trimmed);
      if (reports.isEmpty) return null;

      String? pickImageFrom(Map<String, dynamic> r) {
        final candidates = [
          r['finished_image_url'],
          r['report_image_url'],
          r['report_images'],
          r['image_url'],
          r['asset_image_url'],
        ];
        for (final c in candidates) {
          if (c == null) continue;
          if (c is String) {
            final s = c.trim();
            if (s.isNotEmpty) return s;
          }
          if (c is List) {
            for (final it in c) {
              final s = it?.toString().trim();
              if (s != null && s.isNotEmpty) return s;
            }
          }
        }
        return null;
      }

      for (final r in reports) {
        final img = pickImageFrom(r);
        if (img != null && img.isNotEmpty) {
          _reportImageByAssetId[trimmed] = img;
          return img;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _hydrateAssetTypesForDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final missing = <String>{};
    for (final d in docs) {
      final data = d.data();
      final assetId = (data['asset_id'] ?? '').toString().trim();
      if (assetId.isEmpty) continue;

      // If audits_history already has asset_type, no need to hydrate.
      final rawFromAudit = (data['asset_type'] ?? '').toString().trim();
      if (rawFromAudit.isNotEmpty) continue;

      if (_assetTypeById.containsKey(assetId)) continue;
      missing.add(assetId);
    }

    if (missing.isEmpty) return;

    try {
      final futures = missing.map((id) => FirebaseService().getAssetById(id));
      final results = await Future.wait(futures);
      if (!mounted) return;

      final next = Map<String, String>.from(_assetTypeById);
      for (int i = 0; i < results.length; i++) {
        final assetId = missing.elementAt(i);
        final asset = results[i];
        if (asset == null) continue;

        final rawType = (asset['asset_type'] ?? '').toString().trim();
        if (rawType.isEmpty) continue;

        final typeName = _categoryNameById[rawType] ?? rawType;
        if (typeName.isNotEmpty) {
          next[assetId] = typeName;
        }
      }

      setState(() {
        _assetTypeById
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      // best-effort hydration only
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssetTypes() async {
    setState(() {
      _isLoadingAssetTypes = true;
    });

    try {
      final categories = await FirebaseService().getAssetCategories();
      final assets = await FirebaseService().getAssets();
      if (!mounted) return;

      final types = <String>[];
      final categoryNameById = <String, String>{};
      for (final c in categories) {
        final name = c['name']?.toString().trim();
        final id = c['id']?.toString().trim();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          categoryNameById[id] = name;
        }
        if (name != null && name.isNotEmpty) {
          types.add(name);
        }
      }

      final byId = <String, String>{};
      for (final a in assets) {
        final id = a.assetId.toString().trim();
        final rawType = a.assetType.toString().trim();
        final typeName = categoryNameById[rawType] ?? rawType;
        if (id.isNotEmpty && typeName.isNotEmpty) {
          byId[id] = typeName;
        }
      }

      setState(() {
        _assetTypeById
          ..clear()
          ..addAll(byId);
        _categoryNameById
          ..clear()
          ..addAll(categoryNameById);
        _assetTypes = types;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดประเภทครุภัณฑ์ไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAssetTypes = false;
        });
      }
    }
  }

  bool get _hasAssetTypeFilter => _assetTypeFilter != 'all';

  String _assetTypeLabel() {
    if (!_hasAssetTypeFilter) return 'ทุกประเภทครุภัณฑ์';
    return _assetTypeFilter;
  }

  void _clearAssetTypeFilter() {
    setState(() {
      _assetTypeFilter = 'all';
    });
  }

  Future<void> _pickAssetType() async {
    if (_isLoadingAssetTypes) return;
    if (!mounted) return;

    List<String> liveTypes = _assetTypes;
    bool isLoading =
        liveTypes.isEmpty ||
        _assetTypeById.isEmpty ||
        _categoryNameById.isEmpty;
    String? loadError;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> ensureLoaded() async {
              if (!isLoading) return;
              try {
                final categories = await FirebaseService().getAssetCategories();
                final assets = await FirebaseService().getAssets();

                final nextTypes = <String>[];
                final categoryNameById = <String, String>{};
                for (final c in categories) {
                  final name = c['name']?.toString().trim();
                  final id = c['id']?.toString().trim();
                  if (id != null &&
                      id.isNotEmpty &&
                      name != null &&
                      name.isNotEmpty) {
                    categoryNameById[id] = name;
                  }
                  if (name != null && name.isNotEmpty) {
                    nextTypes.add(name);
                  }
                }

                final byId = <String, String>{};
                for (final a in assets) {
                  final id = a.assetId.toString().trim();
                  final rawType = a.assetType.toString().trim();
                  final typeName = categoryNameById[rawType] ?? rawType;
                  if (id.isNotEmpty && typeName.isNotEmpty) {
                    byId[id] = typeName;
                  }
                }

                if (!context.mounted) return;
                liveTypes = nextTypes;
                loadError = null;
                isLoading = false;

                // sync back to parent cache (best-effort)
                if (mounted) {
                  setState(() {
                    _assetTypes = nextTypes;
                    _assetTypeById
                      ..clear()
                      ..addAll(byId);
                    _categoryNameById
                      ..clear()
                      ..addAll(categoryNameById);
                  });
                }
                setSheetState(() {});
              } catch (e) {
                if (!context.mounted) return;
                loadError = e.toString();
                isLoading = false;
                setSheetState(() {});
              }
            }

            // Fire and forget (runs once)
            ensureLoaded();

            final items = <String>['all', ...liveTypes];

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'เลือกประเภทครุภัณฑ์',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (loadError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'โหลดประเภทครุภัณฑ์ไม่สำเร็จ',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loadError!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                isLoading = true;
                                loadError = null;
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    )
                  else if (liveTypes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'ยังไม่มีประเภทครุภัณฑ์ในระบบ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final v = items[index];
                          final label = v == 'all' ? 'ทุกประเภทครุภัณฑ์' : v;
                          final selected = _assetTypeFilter == v;
                          return ListTile(
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected
                                  ? const Color(0xFF9A2C2C)
                                  : Colors.grey.shade500,
                            ),
                            title: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _assetTypeFilter = v;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Query<Map<String, dynamic>> _baseQuery() {
    final base = FirebaseFirestore.instance.collection('audits_history');
    if (_fallbackOrderByDocId) {
      return base.orderBy(FieldPath.documentId, descending: true);
    }
    return base.orderBy('audited_at', descending: true);
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
      _isLoadingMore = true;
    });

    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _baseQuery().limit(_pageSize).get();
      } on FirebaseException catch (e) {
        if (!_fallbackOrderByDocId && e.code == 'failed-precondition') {
          _fallbackOrderByDocId = true;
          snap = await _baseQuery().limit(_pageSize).get();
        } else {
          rethrow;
        }
      }
      if (!mounted) return;

      setState(() {
        _docs.addAll(snap.docs);
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = snap.docs.length == _pageSize;
      });

      // Best-effort hydration so filtering by type works even when audits_history lacks asset_type.
      await _hydrateAssetTypesForDocs(snap.docs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('โหลดประวัติไม่สำเร็จ: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final last = _lastDoc;
    if (last == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _baseQuery()
            .startAfterDocument(last)
            .limit(_pageSize)
            .get();
      } on FirebaseException catch (e) {
        if (!_fallbackOrderByDocId && e.code == 'failed-precondition') {
          _fallbackOrderByDocId = true;
          snap = await _baseQuery()
              .startAfterDocument(last)
              .limit(_pageSize)
              .get();
        } else {
          rethrow;
        }
      }
      if (!mounted) return;

      setState(() {
        _docs.addAll(snap.docs);
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length == _pageSize;
      });

      // Hydrate types for newly fetched docs.
      await _hydrateAssetTypesForDocs(snap.docs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('โหลดเพิ่มเติมไม่สำเร็จ: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  String _formatDateTime(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _statusText(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return '-';
    return s;
  }

  int _auditStatusCode(dynamic v) {
    if (v is int) return v;
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return 0;
    return int.tryParse(s) ?? 0;
  }

  String _auditStatusText(dynamic v) {
    final code = _auditStatusCode(v);
    if (code == 1) return 'ปกติ';
    if (code == 2) return 'ชำรุด';
    return 'ไม่ทราบสถานะ';
  }

  ({Color color, IconData icon}) _statusUi(dynamic v) {
    final s = _statusText(v);
    if (s == 'ปกติ')
      return (color: const Color(0xFF16A34A), icon: Icons.check_circle);
    if (s == 'ชำรุด')
      return (color: const Color(0xFFEF4444), icon: Icons.cancel);
    return (color: const Color(0xFF6B7280), icon: Icons.help);
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final statusCode = _auditStatusCode(data['audit_status']);
    if (_statusFilter != 'all') {
      if (_statusFilter == 'ปกติ' && statusCode != 1) return false;
      if (_statusFilter == 'ชำรุด' && statusCode != 2) return false;
    }

    if (_hasDateFilter) {
      final dt = _toDate(data['audited_at'] ?? data['audit_at']);
      if (dt == null) return false;

      final range = _dateRange;
      if (range == null) return false;

      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final endExclusive = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));

      if (dt.isBefore(start) || !dt.isBefore(endExclusive)) return false;
    }

    final assetIdRaw = (data['asset_id'] ?? '').toString();
    final assetId = assetIdRaw.toLowerCase();
    final assetName = (data['asset_name'] ?? '').toString().toLowerCase();
    final assetTypeFromDoc = (data['asset_type'] ?? '').toString().trim();
    final rawType = assetTypeFromDoc.isNotEmpty
        ? assetTypeFromDoc
        : (_assetTypeById[assetIdRaw.trim()] ?? '');
    final typeName = _categoryNameById[rawType] ?? rawType;

    if (_assetTypeFilter != 'all' && typeName != _assetTypeFilter) {
      return false;
    }

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final auditorName = (data['auditor_name'] ?? '').toString().toLowerCase();
    final note = (data['note'] ?? data['remark'] ?? data['audit_note'] ?? '')
        .toString()
        .toLowerCase();

    return assetId.contains(q) ||
        assetName.contains(q) ||
        auditorName.contains(q) ||
        note.contains(q);
  }

  List<Map<String, dynamic>> get _visibleItems {
    return _docs
        .map((d) => d.data())
        .where(_matchesFilters)
        .toList(growable: false);
  }

  String _dateFilterLabel() {
    if (_dateRange == null) return 'เลือกช่วงวันที่';
    final r = _dateRange!;
    final sd = _formatDateTime(r.start).split(' ').first;
    final ed = _formatDateTime(r.end).split(' ').first;
    return '$sd - $ed';
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialStart =
        _dateRange?.start ?? now.subtract(const Duration(days: 6));
    final initialEnd = _dateRange?.end ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF9A2C2C)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (!mounted) return;
    if (picked == null) return;

    setState(() {
      _dateRange = picked;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _dateRange = null;
    });
  }

  Future<void> _showLogDetail(Map<String, dynamic> data) async {
    final assetId = (data['asset_id'] ?? '-').toString();
    final assetName = (data['asset_name'] ?? '').toString();
    final auditor = (data['auditor_name'] ?? '-').toString();
    final status = _auditStatusText(data['audit_status']);
    final remark =
        (data['audited_remark'] ??
                data['audit_remark'] ??
                data['note'] ??
                data['remark'] ??
                data['audit_note'] ??
                '')
            .toString();
    final img =
        (data['audited_image_url'] ??
                data['audit_image_url'] ??
                data['evidence_image'] ??
                data['asset_image_url'] ??
                '')
            .toString()
            .trim();
    final ts = _formatDateTime(data['audited_at'] ?? data['audit_at']);
    final statusUi = _statusUi(status);

    if (!mounted) return;

    final Future<String?> remarkFuture = remark.trim().isNotEmpty
        ? Future.value(remark)
        : _getReportRemarkForAsset(assetId);

    final Future<String?> imageFuture = img.isNotEmpty
        ? Future.value(img)
        : _getReportImageForAsset(assetId);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9A2C2C).withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusUi.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(statusUi.icon, color: statusUi.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'รายละเอียดการตรวจสอบ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ts,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusUi.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'ปิด',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Color(0xFF9A2C2C)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailCard(
                          title: 'ข้อมูลครุภัณฑ์',
                          icon: Icons.inventory_2_outlined,
                          iconColor: const Color(0xFF9A2C2C),
                          children: [
                            _buildKv('รหัสครุภัณฑ์', assetId),
                            if (assetName.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildKv('ชื่อครุภัณฑ์', assetName),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          title: 'ข้อมูลการตรวจ',
                          icon: Icons.verified_outlined,
                          iconColor: statusUi.color,
                          children: [
                            _buildKv('ผู้ตรวจสอบ', auditor),
                            const SizedBox(height: 10),
                            _buildKv('ผลการตรวจสอบ', status),
                          ],
                        ),
                        FutureBuilder<String?>(
                          future: remarkFuture,
                          builder: (context, snapshot) {
                            final resolved =
                                snapshot.data?.toString().trim() ?? '';
                            if (resolved.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _buildDetailCard(
                                title: 'หมายเหตุ',
                                icon: Icons.notes_outlined,
                                iconColor: const Color(0xFF9A2C2C),
                                children: [
                                  Text(
                                    resolved,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        FutureBuilder<String?>(
                          future: imageFuture,
                          builder: (context, snapshot) {
                            final resolved = snapshot.data?.trim() ?? '';
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                resolved.isEmpty) {
                              return _buildDetailCard(
                                title: 'รูปประกอบ',
                                icon: Icons.photo_outlined,
                                iconColor: const Color(0xFF9A2C2C),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ],
                              );
                            }

                            if (resolved.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return _buildDetailCard(
                              title: 'รูปประกอบ',
                              icon: Icons.photo_outlined,
                              iconColor: const Color(0xFF9A2C2C),
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () =>
                                        _openNetworkImagePreview(resolved),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 10,
                                      child: Image.network(
                                        resolved,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.grey.shade400,
                                                    size: 44,
                                                  ),
                                                ),
                                              );
                                            },
                                        loadingBuilder:
                                            (context, child, progress) {
                                              if (progress == null)
                                                return child;
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9A2C2C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'ปิด',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNetworkImagePreview(String url) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        color: Colors.white,
                        child: const Text('ไม่สามารถแสดงรูปได้'),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildKv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$k:',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9A2C2C),
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            softWrap: true,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        foregroundColor: Colors.white,
        title: const Text(
          'ประวัติการตรวจสอบอุปกรณ์',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _isLoadingMore ? null : _loadFirstPage,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        color: const Color(0xFF9A2C2C),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหา (รหัส/ชื่อครุภัณฑ์ / ผู้ตรวจ / หมายเหตุ)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _FilterChipButton(
                  label: 'ทั้งหมด',
                  selected: _statusFilter == 'all',
                  onTap: () => setState(() => _statusFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'ปกติ',
                  selected: _statusFilter == 'ปกติ',
                  onTap: () => setState(() => _statusFilter = 'ปกติ'),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'ชำรุด',
                  selected: _statusFilter == 'ชำรุด',
                  onTap: () => setState(() => _statusFilter = 'ชำรุด'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickAssetType,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _hasAssetTypeFilter
                            ? const Color(0xFF9A2C2C)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _hasAssetTypeFilter
                              ? const Color(0xFF9A2C2C)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _isLoadingAssetTypes
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.category_outlined,
                                  size: 16,
                                  color: _hasAssetTypeFilter
                                      ? Colors.white
                                      : const Color(0xFF9A2C2C),
                                ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _assetTypeLabel(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _hasAssetTypeFilter
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.expand_more,
                            size: 20,
                            color: _hasAssetTypeFilter
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_hasAssetTypeFilter) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _clearAssetTypeFilter,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickCustomDateRange,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _hasDateFilter
                            ? const Color(0xFF9A2C2C)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _hasDateFilter
                              ? const Color(0xFF9A2C2C)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month,
                            size: 16,
                            color: _hasDateFilter
                                ? Colors.white
                                : const Color(0xFF9A2C2C),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dateFilterLabel(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _hasDateFilter
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_hasDateFilter) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _clearDateFilter,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            if (_docs.isEmpty && _isLoadingMore)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    _docs.isEmpty
                        ? 'ยังไม่มีประวัติการตรวจสอบ'
                        : 'ไม่พบรายการที่ตรงกับตัวกรอง',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else
              ...visible.map((data) {
                final assetId = (data['asset_id'] ?? '-').toString();
                final assetName = (data['asset_name'] ?? '').toString();
                final auditor = (data['auditor_name'] ?? '-').toString();
                final status = _auditStatusText(data['audit_status']);
                final remark =
                    (data['audited_remark'] ??
                            data['audit_remark'] ??
                            data['note'] ??
                            data['remark'] ??
                            data['audit_note'] ??
                            '')
                        .toString();
                final ts = _formatDateTime(
                  data['audited_at'] ?? data['audit_at'],
                );
                final ui = _statusUi(status);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showLogDetail(data),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ui.color.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: ui.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(ui.icon, color: ui.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        assetId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ui.color,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (assetName.trim().isNotEmpty) ...[
                                  Text(
                                    assetName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  'ผู้ตรวจ: $auditor',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                if (remark.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    remark,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  ts,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
              }),

            if (_docs.isNotEmpty) ...[
              const SizedBox(height: 6),
              if (_hasMore)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingMore ? null : _loadMore,
                    icon: _isLoadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(
                      _isLoadingMore ? 'กำลังโหลด...' : 'โหลดเพิ่มเติม',
                    ),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'แสดงครบแล้ว',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF9A2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF9A2C2C) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
