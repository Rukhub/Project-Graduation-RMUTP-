import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'services/firebase_service.dart';
import 'app_drawer.dart';
// import 'models/location_model.dart';
// import 'models/asset_model.dart';

class InspectEquipmentScreen extends StatefulWidget {
  final Map<String, dynamic>? equipment;
  final String? roomName;

  const InspectEquipmentScreen({super.key, this.equipment, this.roomName});

  @override
  State<InspectEquipmentScreen> createState() => _InspectEquipmentScreenState();
}

class _InspectEquipmentScreenState extends State<InspectEquipmentScreen> {
  // Selection State
  int selectedFloor = 1;
  String? selectedRoom;
  dynamic selectedRoomId;
  String? selectedEquipmentId;
  Map<String, dynamic>? currentEquipment;
  final TextEditingController _equipmentSearchController =
      TextEditingController();
  String _equipmentSearchQuery = '';

  // Form State
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  List<String> inspectorImages = [];
  String selectedStatus = 'ปกติ';

  // API Data
  List<Map<String, dynamic>> locations = [];
  List<int> availableFloors = [];
  List<Map<String, dynamic>> assetsInRoom = [];
  bool isLoadingLocations = true;
  bool isLoadingAssets = false;

  bool _isCreatingRepairAgain = false;

  final List<Map<String, dynamic>> statusList = [
    {'name': 'ปกติ', 'color': Color(0xFF99CD60), 'icon': Icons.check_circle},
    {'name': 'ชำรุด', 'color': Color(0xFFE44F5A), 'icon': Icons.cancel},
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
    if (widget.equipment != null) {
      currentEquipment = widget.equipment;
      selectedRoom = widget.roomName;
      selectedEquipmentId =
          widget.equipment!['asset_id'] ?? widget.equipment!['id'];
      selectedStatus = _statusToText(widget.equipment!['asset_status']);

      // Fetch latest asset fields for lock enforcement.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshCurrentEquipmentFromFirestore();
      });
    }

    // Autofill checker name
    final currentUser = ApiService().currentUser;
    if (currentUser != null) {
      if (currentUser['fullname'] != null &&
          currentUser['fullname'].toString().isNotEmpty) {
        _nameController.text = currentUser['fullname'];
      } else if (currentUser['username'] != null) {
        _nameController.text = currentUser['username'];
      }
    }

    _loadLocations();

    // Refresh profile from Firestore so the displayed/saved name matches
    // the currently logged-in account (prevents stale fullname issues).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAndAutofillCheckerName();
    });
  }

  void _openLocalImagePreview(String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.file(
                    File(path),
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
                  onTap: () => Navigator.pop(dialogContext),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
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

  Future<void> _showRepairAgainDialog() async {
    if (currentEquipment == null) return;
    if (_isCreatingRepairAgain) return;

    await ApiService().refreshCurrentUser();
    if (!mounted) return;

    final reasonController = TextEditingController();
    File? pickedImage;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('ซ่อมอีกครั้ง'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
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
                      const Text(
                        'กรุณาระบุเหตุผลที่ต้องกลับมาอยู่ระหว่างซ่อม:',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'เช่น พบวิธีซ่อมใหม่/เปลี่ยนอะไหล่/ส่งซ่อมภายนอก...',
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
                                                Icons.photo_library_outlined,
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
                            pickedImage == null ? 'แนบรูปภาพ' : 'เปลี่ยนรูปภาพ',
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
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('กรุณากรอกเหตุผล')),
                  );
                  return;
                }

                final assetId =
                    (currentEquipment!['asset_id'] ?? currentEquipment!['id'])
                        .toString();
                if (assetId.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ไม่พบรหัสครุภัณฑ์')),
                  );
                  return;
                }

                final currentUserUid =
                    ApiService().currentUser?['uid']?.toString() ??
                    (ApiService().currentUser?['user_id']?.toString() ??
                        'unknown_uid');
                final currentUserName =
                    ApiService().currentUser?['fullname']?.toString() ??
                    _nameController.text.trim();

                setState(() {
                  _isCreatingRepairAgain = true;
                });

                try {
                  // Find previous report id (latest report doc for this asset)
                  final reports = await FirebaseService().getReports(assetId);
                  if (reports.isEmpty) {
                    throw Exception('ไม่พบรายการแจ้งซ่อมเดิมสำหรับอ้างอิง');
                  }

                  Map<String, dynamic> prev = reports.first;
                  final cancelled = reports.where(
                    (r) => r['report_status']?.toString() == 'cancelled',
                  );
                  if (cancelled.isNotEmpty) {
                    prev = cancelled.first;
                  }

                  final prevId = prev['id']?.toString();
                  if (prevId == null || prevId.trim().isEmpty) {
                    throw Exception('ไม่พบรายการแจ้งซ่อมเดิมสำหรับอ้างอิง');
                  }

                  String? uploadedReportImageUrl;
                  if (pickedImage != null) {
                    uploadedReportImageUrl = await FirebaseService()
                        .uploadReportImage(pickedImage!, assetId);
                  }

                  final newReportId = await FirebaseService()
                      .createRepairAgainReport(
                        assetId: assetId,
                        previousReportId: prevId,
                        reason: reason,
                        workerId: currentUserUid,
                        workerName: currentUserName.isNotEmpty
                            ? currentUserName
                            : 'Unknown Admin',
                        reportImageUrl: uploadedReportImageUrl,
                      );

                  await FirebaseService().updateAsset(assetId, {
                    'asset_status': 3,
                    'repairer_id': currentUserUid,
                    'auditor_name': currentUserName,
                    'condemned_at': FieldValue.delete(),
                  });

                  if (!mounted) return;
                  Navigator.pop(context);

                  setState(() {
                    currentEquipment = {
                      ...?currentEquipment,
                      'asset_status': 3,
                      'repairer_id': currentUserUid,
                      'auditor_name': currentUserName,
                    };
                    selectedStatus = 'อยู่ระหว่างซ่อม';
                  });

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('เปิดรอบซ่อมอีกครั้งแล้ว'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  debugPrint('✅ Repair-again created report: $newReportId');
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('ทำรายการไม่สำเร็จ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _isCreatingRepairAgain = false;
                    });
                  }
                }
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshAndAutofillCheckerName() async {
    await ApiService().refreshCurrentUser();
    if (!mounted) return;
    final u = ApiService().currentUser;
    final freshName = u?['fullname']?.toString();
    if (freshName != null && freshName.isNotEmpty) {
      // Do not override if user already typed a different value.
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim() == (u?['username']?.toString() ?? '')) {
        setState(() {
          _nameController.text = freshName;
        });
      }
    }
  }

  Future<void> _refreshCurrentEquipmentFromFirestore() async {
    final eq = currentEquipment;
    if (eq == null) return;

    final assetId = (eq['asset_id'] ?? eq['id'])?.toString();
    if (assetId == null || assetId.isEmpty) return;

    try {
      final latest = await FirebaseService().getAssetById(assetId);
      if (!mounted) return;
      if (latest == null) return;

      setState(() {
        currentEquipment = {...eq, ...latest};
        selectedStatus = _statusToText(
          latest['asset_status'] ?? selectedStatus,
          repairerId: latest['repairer_id'],
        );
      });
    } catch (e) {
      debugPrint('🚨 Error refreshing equipment from Firestore: $e');
    }
  }

  String _statusToText(dynamic status, {dynamic repairerId}) {
    if (status is int) {
      if (status == 1) return 'ปกติ';
      if (status == 2) return 'ชำรุด';
      if (status == 3) {
        if (repairerId != null && repairerId.toString().isNotEmpty) {
          return 'อยู่ระหว่างซ่อม';
        }
        return 'รอดำเนินการ';
      }
      if (status == 4) return 'ซ่อมไม่ได้';
    }
    final s = status?.toString();
    if (s == null || s.isEmpty || s == 'null') return 'ปกติ';
    return s;
  }

  bool get _isQuickConfirmStatus => selectedStatus == 'ปกติ';

  bool get _shouldShowRemarkSection => selectedStatus != 'ปกติ';

  bool get _shouldShowImageSection => true;

  bool get _requiresEvidence => false;

  String? get _currentUid => ApiService().currentUser?['uid']?.toString();

  bool get _isLockedByOther {
    final eq = currentEquipment;
    if (eq == null) return false;
    final status = _statusToText(
      eq['asset_status'],
      repairerId: eq['repairer_id'],
    );
    if (status != 'อยู่ระหว่างซ่อม') return false;

    final repairerId = eq['repairer_id']?.toString();
    final myUid = _currentUid;
    if (repairerId == null || repairerId.isEmpty || myUid == null) return false;
    return repairerId != myUid;
  }

  String? get _lockedByName {
    final eq = currentEquipment;
    if (eq == null) return null;
    final name = (eq['auditor_name'] ?? eq['inspectorName'])?.toString();
    if (name == null || name.trim().isEmpty) return null;
    return name.trim();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remarkController.dispose();
    _equipmentSearchController.dispose();
    super.dispose();
  }

  int? _parseFloorInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final digits = RegExp(r'\d+').firstMatch(s)?.group(0);
    if (digits == null) return null;
    return int.tryParse(digits);
  }

  Future<void> _loadLocations() async {
    setState(() => isLoadingLocations = true);
    try {
      final data = await FirebaseService().getLocations();
      setState(() {
        locations = data
            .map(
              (loc) => {
                'location_id': loc.locationId,
                'room_name': loc.roomName,
                'floor': loc.floor,
              },
            )
            .toList();
        final floorsSet = <int>{};
        for (final loc in locations) {
          final f = _parseFloorInt(loc['floor']);
          if (f != null) floorsSet.add(f);
        }
        availableFloors = floorsSet.toList()..sort();
        if (availableFloors.isNotEmpty &&
            !availableFloors.contains(selectedFloor)) {
          selectedFloor = availableFloors.first;
          selectedRoom = null;
          selectedRoomId = null;
          selectedEquipmentId = null;
          currentEquipment = null;
          _equipmentSearchController.clear();
          _equipmentSearchQuery = '';
          assetsInRoom = [];
        }
        isLoadingLocations = false;
      });
    } catch (e) {
      debugPrint('🚨 Error loading Firebase locations: $e');
      setState(() => isLoadingLocations = false);
    }
  }

  Future<void> _loadAssetsInRoom(dynamic locationId) async {
    setState(() {
      isLoadingAssets = true;
      assetsInRoom = [];
    });
    try {
      // Use getAssetsByLocationStream but just for a one-time fetch or similar
      // Better to have a Future version in FirebaseService
      final snapshot = await FirebaseService()
          .getAssets(); // Simplified for now
      final targetId = locationId?.toString();
      final roomAssets = snapshot
          .where((a) => a.locationId?.toString() == targetId)
          .toList();

      setState(() {
        assetsInRoom = roomAssets
            .map(
              (a) => {
                'asset_id': a.assetId,
                'id': a.assetId,
                'asset_name': a.assetName,
                'asset_type': a.assetType,
                'asset_status': a.status,
                'status': _statusToText(a.status),
                'status_raw': a.status,
                'repairer_id': a.repairerId,
                'auditor_name': a.checkerName,
                'asset_image_url': a.imageUrl,
                'reporter_name': a.reporterName,
                'issue_detail': a.issueDetail,
                'report_images': a.reportImages,
              },
            )
            .toList();
        isLoadingAssets = false;
      });
    } catch (e) {
      debugPrint('🚨 Error loading assets: $e');
      setState(() => isLoadingAssets = false);
    }
  }

  List<Map<String, dynamic>> getRoomsForFloor(int floor) {
    return locations.where((loc) {
      final f = _parseFloorInt(loc['floor']);
      return f == floor;
    }).toList();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      if (!mounted) return;
      setState(() {
        inspectorImages = [image.path];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกรูปได้: $e')));
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      if (!mounted) return;
      setState(() {
        inspectorImages = [photo.path];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถถ่ายรูปได้: $e')));
    }
  }

  void _deleteImage(int index) {
    setState(() {
      inspectorImages = [];
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกรูปจากคลัง'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    ).then((source) {
      if (source == null) return;
      if (source == ImageSource.camera) {
        _takePhoto();
      } else {
        _pickImageFromGallery();
      }
    });
  }

  Future<void> _submitInspection() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (currentEquipment == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกครุภัณฑ์'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Always refresh before saving so the checker name is not stale.
    await ApiService().refreshCurrentUser();
    if (!mounted) return;

    final refreshedUser = ApiService().currentUser;
    final refreshedFullname = refreshedUser?['fullname']?.toString();

    // === Lock enforcement (same idea as KrupanRoom / EquipmentDetailScreen) ===
    // If another account started repair, do not allow saving from this screen.
    final assetIdForLock =
        (currentEquipment!['asset_id'] ?? currentEquipment!['id']).toString();
    final latestAsset = await FirebaseService().getAssetById(assetIdForLock);
    if (!mounted) return;
    if (latestAsset != null) {
      final latestStatus = _statusToText(latestAsset['asset_status']);
      final latestRepairerId = latestAsset['repairer_id']?.toString();
      final myUid = ApiService().currentUser?['uid']?.toString();

      if (latestAsset['repairer_id'] != null &&
          latestAsset['repairer_id'].toString().trim().isNotEmpty &&
          myUid != null &&
          latestRepairerId != myUid) {
        final lockedBy = (latestAsset['auditor_name'])?.toString();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              lockedBy?.isNotEmpty == true
                  ? 'ครุภัณฑ์นี้ถูกล็อคโดย $lockedBy'
                  : 'ครุภัณฑ์นี้ถูกล็อคโดยผู้อื่น',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }
    }

    if ((refreshedFullname == null || refreshedFullname.trim().isEmpty) &&
        _nameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อผู้ตรวจ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Inspection = confirm condition only (ปกติ/ชำรุด)

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5593E4)),
      ),
    );

    // Get checker_id from current user
    final currentUser = ApiService().currentUser;
    // Bo Request: ใช้ checker_id (int)
    final checkerId = currentUser?['user_id'] ?? currentUser?['uid'];
    final currentUid = currentUser?['uid']?.toString();
    final currentFullname = currentUser?['fullname']?.toString();

    if (checkerId == null) {
      if (!context.mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลรหัสผู้ใช้ (User ID) กรุณา login ใหม่'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final assetId = (currentEquipment!['asset_id'] ?? currentEquipment!['id'])
        .toString();

    // --- 1. Upload Image (If any) ---
    String? finalImageUrl; // Variable to hold uploaded URL

    if (inspectorImages.isNotEmpty) {
      try {
        // Upload the latest image taken
        File imgFile = File(inspectorImages.last);
        finalImageUrl = await FirebaseService().uploadRepairImage(
          imgFile,
          assetId,
        );
        debugPrint('📸 Uploaded Inspection Image: $finalImageUrl');
      } catch (e) {
        debugPrint('🚨 Image upload failed: $e');
        // Decide: Should we fail or continue without image?
        // For now, continue but maybe warn? Or just continue.
      }
    }

    final remarkText = _remarkController.text.trim();
    final shouldAttachRemark = remarkText.isNotEmpty;

    try {
      // --- 2. Derive numeric status ---
      int statusNum = 1;
      if (selectedStatus == 'ปกติ') {
        statusNum = 1;
      } else if (selectedStatus == 'ชำรุด') {
        statusNum = 2;
      }

      // --- 5. Create Audit Log in Firestore (for EquipmentDetailScreen history) ---
      // IMPORTANT:
      // - "อยู่ระหว่างซ่อม" and "ซ่อมเสร็จ" and "ซ่อมไม่ได้" should not create audits_history
      //   (align with EquipmentDetailScreen flows)
      if (statusNum == 1 || statusNum == 2) {
        await FirebaseService().createAuditLog({
          'asset_id': assetId,
          'auditor_id': currentUid ?? checkerId.toString(),
          'auditor_name':
              (currentFullname != null && currentFullname.trim().isNotEmpty)
              ? currentFullname.trim()
              : _nameController.text.trim(),
          'audit_status': statusNum,
          'audited_image_url': finalImageUrl ?? '',
          'audited_remark': shouldAttachRemark ? remarkText : '',
        });
      }

      // --- 5.1 If inspection result is damaged -> create reports_history (same as report_problem_screen) ---
      if (statusNum == 2) {
        try {
          await FirebaseService().createReport({
            'asset_id': assetId,
            'asset_name': currentEquipment!['asset_name'],
            'reporter_id': (currentUid != null && currentUid.trim().isNotEmpty)
                ? currentUid.trim()
                : 'unknown_uid',
            'reporter_name':
                (currentFullname != null && currentFullname.trim().isNotEmpty)
                ? currentFullname.trim()
                : _nameController.text.trim(),
            'report_remark': remarkText,
            if (_shouldShowImageSection && finalImageUrl != null)
              'report_image_url': finalImageUrl,
            'report_status': 1,
            'reported_at': FieldValue.serverTimestamp(),
          }, shouldCreateAuditLog: false);
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('DUPLICATE_OPEN_REPORT')) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('มีการแจ้งปัญหาแล้ว กรุณารอเจ้าหน้าที่ดำเนินการ'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            rethrow;
          }
        }
      }

      // --- 6. Update Asset Status in Firestore ---
      await FirebaseService().updateAsset(assetId, {
        'asset_status': statusNum,
        'auditor_name':
            (currentFullname != null && currentFullname.trim().isNotEmpty)
            ? currentFullname.trim()
            : _nameController.text.trim(),
        'audited_at': FieldValue.serverTimestamp(),
        'repairer_id': null,
        'condemned_at': FieldValue.delete(),
      });

      if (!mounted) return;
      // Close Loading Dialog
      Navigator.pop(context);

      final successResult = {'success': true};
      _handleSubmissionResult(successResult, assetId, messenger, navigator);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleSubmissionResult(
    dynamic result,
    String assetId,
    ScaffoldMessengerState messenger,
    NavigatorState navigator,
  ) {
    if (result != null && result['success'] == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('บันทึกการตรวจสอบเรียบร้อยแล้ว')),
            ],
          ),
          backgroundColor: const Color(0xFF99CD60),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Return result to previous screen
      navigator.pop({
        'status': selectedStatus,
        'auditor_name': _nameController.text.trim(),
        'remark': _remarkController.text.trim(),
      });
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result?['message'] ?? 'เกิดข้อผิดพลาด'),
          backgroundColor: const Color(0xFFE44F5A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSelectionMode = widget.equipment == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      drawer: const AppDrawer(),
      body: isLoadingLocations
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5593E4)),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: const Color(0xFF5593E4),
                  leading: IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Color(0xFF5593E4),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    Builder(
                      builder: (context) {
                        return IconButton(
                          tooltip: 'เมนู',
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        );
                      },
                    ),
                  ],
                  centerTitle: true,
                  title: const Text(
                    'ตรวจสอบอุปกรณ์',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  expandedHeight: 120,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF5593E4), Color(0xFF2E6BC8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Text(
                              currentEquipment == null
                                  ? 'ขั้นตอนที่ 1: เลือกครุภัณฑ์'
                                  : 'ขั้นตอนที่ 2: บันทึกผลการตรวจสอบ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isSelectionMode) ...[
                          _buildSelectionSection(),
                          const SizedBox(height: 16),
                        ],
                        if (currentEquipment != null) ...[
                          _buildEquipmentInfoCard(),
                          const SizedBox(height: 16),
                          if (currentEquipment!['reporter_name'] != null ||
                              currentEquipment!['reporterName'] != null)
                            _buildReporterInfo(),
                          const SizedBox(height: 16),
                          _buildInspectionForm(),
                        ] else if (isSelectionMode) ...[
                          _buildEmptyState(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: (currentEquipment == null || _isLockedByOther)
                  ? null
                  : _submitInspection,
              icon: const Icon(Icons.task_alt_rounded),
              label: Text(
                currentEquipment == null
                    ? 'เลือกครุภัณฑ์ก่อนจึงบันทึกได้'
                    : _isLockedByOther
                    ? 'ถูกล็อคโดยผู้อื่น'
                    : 'บันทึกการตรวจสอบ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5593E4),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSection() {
    final roomsInFloor = getRoomsForFloor(selectedFloor);
    final filteredAssets = assetsInRoom.where((eq) {
      if (_equipmentSearchQuery.trim().isEmpty) return true;
      final q = _equipmentSearchQuery.trim().toLowerCase();
      final assetId = (eq['asset_id'] ?? eq['id']).toString().toLowerCase();
      final assetType = (eq['asset_type'] ?? eq['type'])
          .toString()
          .toLowerCase();
      return assetId.contains(q) || assetType.contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: Color(0xFF5593E4),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'เลือกห้องและครุภัณฑ์',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // เลือกชั้น
          _buildDropdownLabel('ชั้น'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _buildDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedFloor,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF5593E4),
                ),
                items: availableFloors.map((floor) {
                  return DropdownMenuItem(
                    value: floor,
                    child: Text(
                      'ชั้น $floor',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedFloor = value;
                    selectedRoom = null;
                    selectedRoomId = null;
                    selectedEquipmentId = null;
                    currentEquipment = null;
                    _equipmentSearchController.clear();
                    _equipmentSearchQuery = '';
                    assetsInRoom = [];
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // เลือกห้อง
          _buildDropdownLabel('ห้อง'),
          if (roomsInFloor.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF5593E4).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF5593E4)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ไม่มีห้องในชั้น $selectedFloor',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (roomsInFloor.isEmpty) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _buildDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRoom,
                hint: Text(
                  roomsInFloor.isEmpty ? 'ไม่มีห้องในชั้นนี้' : 'เลือกห้อง',
                ),
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF5593E4),
                ),
                items: roomsInFloor.map((room) {
                  return DropdownMenuItem<String>(
                    value: room['room_name'] as String,
                    child: Text(
                      room['room_name'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: roomsInFloor.isEmpty
                    ? null
                    : (value) {
                        final room = roomsInFloor.firstWhere(
                          (r) => r['room_name'] == value,
                        );
                        setState(() {
                          selectedRoom = value;
                          selectedRoomId = room['location_id'] ?? room['id'];
                          selectedEquipmentId = null;
                          currentEquipment = null;
                          _equipmentSearchController.clear();
                          _equipmentSearchQuery = '';
                        });
                        if (selectedRoomId != null) {
                          _loadAssetsInRoom(selectedRoomId);
                        }
                      },
              ),
            ),
          ),
          const SizedBox(height: 18),

          _buildDropdownLabel('ครุภัณฑ์'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _buildDropdownDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _equipmentSearchController,
                  enabled: !isLoadingAssets && selectedRoomId != null,
                  decoration: InputDecoration(
                    hintText: selectedRoomId == null
                        ? 'กรุณาเลือกห้องก่อน'
                        : 'ค้นหาด้วยรหัส/ประเภทครุภัณฑ์',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F7FB),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _equipmentSearchQuery = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (isLoadingAssets)
                  const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (selectedRoomId == null)
                  Text(
                    'เลือกห้องเพื่อแสดงรายการครุภัณฑ์',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  )
                else if (filteredAssets.isEmpty)
                  Text(
                    assetsInRoom.isEmpty
                        ? 'ไม่พบครุภัณฑ์ในห้องนี้'
                        : 'ไม่พบครุภัณฑ์ที่ตรงกับคำค้นหา',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredAssets.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final eq = filteredAssets[index];
                        final assetId = (eq['asset_id'] ?? eq['id']).toString();
                        final assetType = (eq['asset_type'] ?? eq['type'])
                            .toString();
                        final isSelected = selectedEquipmentId == assetId;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: isSelected
                              ? const Color(0xFFEAF2FF)
                              : Colors.transparent,
                          title: Text(
                            assetId,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            assetType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.chevron_right,
                            color: isSelected
                                ? const Color(0xFF99CD60)
                                : Colors.grey.shade400,
                          ),
                          onTap: () {
                            () async {
                              final latest = await FirebaseService()
                                  .getAssetById(assetId);
                              if (!mounted) return;
                              setState(() {
                                selectedEquipmentId = assetId;
                                currentEquipment = {...eq, ...?latest};
                                selectedStatus = _statusToText(
                                  (latest?['status'] ?? eq['status']),
                                );
                              });
                            }();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentInfoCard() {
    final status = _statusToText(currentEquipment?['status']);
    Color statusColor = status == 'ปกติ'
        ? const Color(0xFF99CD60)
        : (status == 'ชำรุด'
              ? const Color(0xFFE44F5A)
              : const Color(0xFFFECC52));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5593E4).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5593E4).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5593E4).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.computer,
              color: Color(0xFF5593E4),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (currentEquipment?['asset_id'] ??
                                currentEquipment?['id'] ??
                                'ไม่ระบุรหัส')
                            .toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 14,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${currentEquipment?['asset_type'] ?? currentEquipment?['type'] ?? ''} • ${selectedRoom ?? widget.roomName ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReporterInfo() {
    final reporterName =
        currentEquipment!['reporter_name'] ?? currentEquipment!['reporterName'];
    final issueDetail =
        currentEquipment!['issue_detail'] ?? currentEquipment!['reportReason'];

    if (reporterName == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE44F5A).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.report_problem, color: Color(0xFFE44F5A), size: 24),
              SizedBox(width: 10),
              Text(
                'ปัญหาที่แจ้ง',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFFE44F5A), size: 18),
              const SizedBox(width: 8),
              Text(
                'ผู้แจ้ง: $reporterName',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          if (issueDetail != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'รายละเอียด: $issueDetail',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInspectionForm() {
    return Column(
      children: [
        if (_isLockedByOther) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _lockedByName != null
                        ? 'กำลังซ่อมโดย: ${_lockedByName!}\nคุณไม่สามารถเปลี่ยนสถานะได้'
                        : 'ครุภัณฑ์นี้กำลังอยู่ระหว่างซ่อมโดยผู้อื่น\nคุณไม่สามารถเปลี่ยนสถานะได้',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        // ชื่อผู้ตรวจ
        _buildFormCard(
          icon: Icons.person_search,
          title: 'ชื่อผู้ตรวจ',
          required: true,
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'กรอกชื่อ-นามสกุล',
              prefixIcon: Icon(Icons.edit, color: Colors.grey.shade500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF5593E4),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ผลการตรวจสอบ
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.assignment_turned_in,
                    color: Color(0xFF5593E4),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'ผลการตรวจสอบ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    ' *',
                    style: TextStyle(color: Color(0xFF5593E4), fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...statusList.map((status) {
                bool isSelected = selectedStatus == status['name'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      if (_isLockedByOther) return;
                      final nextStatus = status['name'] as String;
                      setState(() {
                        selectedStatus = nextStatus;

                        final bool nextShowRemark = nextStatus != 'ปกติ';
                        if (!nextShowRemark) {
                          _remarkController.clear();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (status['color'] as Color).withValues(alpha: 0.15)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? status['color'] as Color
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? status['color'] as Color
                                : Colors.grey,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            status['icon'] as IconData,
                            color: status['color'] as Color,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            status['name'] as String,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? status['color'] as Color
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // หมายเหตุ - แสดงทุกสถานะยกเว้น ปกติ / อยู่ระหว่างซ่อม
        if (_shouldShowRemarkSection) ...[
          _buildFormCard(
            icon: Icons.note_alt,
            title: 'หมายเหตุ',
            required: _requiresEvidence,
            child: TextField(
              controller: _remarkController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _requiresEvidence
                    ? 'ระบุเหตุผลที่ซ่อมไม่ได้...'
                    : 'เช่น พบฝุ่นเยอะ, ปลั๊กหลวม (ถ้ามี)',
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // รูปภาพ - แสดงเฉพาะ ชำรุด / ซ่อมไม่ได้
          if (_shouldShowImageSection) ...[
            _buildImageSection(),
            const SizedBox(height: 30),
          ],
        ],

        // ถ้าสถานะเป็น "ปกติ" ให้เว้นระยะก่อนปุ่มบันทึก
        if (selectedStatus == 'ปกติ') const SizedBox(height: 10),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFormCard({
    required IconData icon,
    required String title,
    required bool required,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF5593E4), size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(color: Color(0xFF5593E4), fontSize: 18),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.photo_camera, color: Color(0xFF5593E4), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'รูปภาพการตรวจสอบ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5593E4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${inspectorImages.length} รูป',
                  style: const TextStyle(
                    color: Color(0xFF5593E4),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          inspectorImages.isEmpty
              ? _buildEmptyImageState()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _openLocalImagePreview(inspectorImages.first),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 280,
                          color: Colors.grey.shade100,
                          child: Image.file(
                            File(inspectorImages.first),
                            width: double.infinity,
                            height: 280,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  'ไม่สามารถแสดงรูปได้',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showImageSourceDialog,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('เปลี่ยนรูป'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5593E4),
                            side: BorderSide(
                              color: const Color(
                                0xFF5593E4,
                              ).withValues(alpha: 0.4),
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: () => _deleteImage(0),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('ลบ'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5593E4), Color(0xFF3D7BC4)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5593E4).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _submitInspection,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.verified, color: Colors.white, size: 26),
                SizedBox(width: 14),
                Text(
                  'บันทึกการตรวจสอบ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search, size: 70, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'กรุณาเลือกครุภัณฑ์เพื่อตรวจสอบ',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  BoxDecoration _buildDropdownDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade300),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildEmptyImageState() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(35),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 55,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Text(
              'ยังไม่มีรูปภาพ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showImageSourceDialog,
              icon: const Icon(
                Icons.add_photo_alternate,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'เพิ่มรูปภาพ',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5593E4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
      onTap: _showImageSourceDialog,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF5593E4).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF5593E4).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.add_photo_alternate,
          color: Color(0xFF5593E4),
          size: 38,
        ),
      ),
    );
  }

  Widget _buildImageCard(int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: DecorationImage(
              image: FileImage(File(inspectorImages[index])),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: InkWell(
            onTap: () => _deleteImage(index),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFE44F5A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
