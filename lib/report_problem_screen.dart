import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'app_drawer.dart';
import 'api_service.dart';
import 'services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'models/location_model.dart';
// import 'models/asset_model.dart';

class ReportProblemScreen extends StatefulWidget {
  // รับข้อมูลแบบ Optional เพราะถ้าเข้ามาจากหน้า Menu จะยังไม่มีข้อมูล
  final Map<String, dynamic>? equipment;
  final String? roomName;

  const ReportProblemScreen({super.key, this.equipment, this.roomName});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  // State สำหรับการเลือกครุภัณฑ์
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
  final TextEditingController _reasonController = TextEditingController();
  List<String> reportImages = [];

  bool _hasOpenReport = false;
  bool _isCheckingOpenReport = false;
  String? _openReportReporterName;

  // API Data
  List<Map<String, dynamic>> locations = [];
  List<int> availableFloors = [];
  List<Map<String, dynamic>> assetsInRoom = [];
  bool isLoadingLocations = true;
  bool isLoadingAssets = false;
  Map<String, String> categoryMap = {};

  @override
  void initState() {
    super.initState();
    // ถ้ามีข้อมูลส่งมา (จากหน้า Detail) ให้ใช้เลย
    if (widget.equipment != null && widget.roomName != null) {
      currentEquipment = widget.equipment;
      selectedRoom = widget.roomName;
      selectedEquipmentId =
          widget.equipment!['asset_id'] ?? widget.equipment!['id'];
    }

    // Autofill reporter name from logged-in user
    final currentUser = ApiService().currentUser;
    if (currentUser != null && currentUser['fullname'] != null) {
      _nameController.text = currentUser['fullname'];
    }

    _loadLocations();
    _loadCategories();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOpenReportState(showSnackbar: false);
    });
  }

  Future<void> _refreshOpenReportState({required bool showSnackbar}) async {
    final eq = currentEquipment;
    if (eq == null) {
      if (!mounted) return;
      setState(() {
        _hasOpenReport = false;
        _isCheckingOpenReport = false;
        _openReportReporterName = null;
      });
      return;
    }

    final assetId = (eq['asset_id'] ?? eq['id'])?.toString() ?? '';
    if (assetId.trim().isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isCheckingOpenReport = true;
    });

    bool hasOpen = false;
    String? reporterName;
    try {
      final open = await FirebaseService().getLatestOpenReportForAsset(
        assetId.trim(),
      );
      if (open != null) {
        hasOpen = true;
        reporterName = (open['reporter_name'] ?? open['reporterName'])
            ?.toString();
      } else {
        hasOpen = false;
        reporterName = null;
      }
    } catch (_) {
      hasOpen = false;
      reporterName = null;
    }

    if (!mounted) return;
    setState(() {
      _hasOpenReport = hasOpen;
      _isCheckingOpenReport = false;
      _openReportReporterName = reporterName;
    });

    if (showSnackbar && hasOpen) {
      final who =
          (_openReportReporterName != null &&
              _openReportReporterName!.trim().isNotEmpty)
          ? _openReportReporterName!.trim()
          : 'มีคนอื่น';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$who แจ้งปัญหาแล้ว กรุณารอเจ้าหน้าที่ดำเนินการ'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await FirebaseService().getAssetCategories();
      if (mounted) {
        setState(() {
          categoryMap = {
            for (var cat in categories)
              if (cat['id'] != null)
                cat['id'].toString(): cat['name']?.toString() ?? '',
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
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

  int? _parseFloorInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final digits = RegExp(r'\d+').firstMatch(s)?.group(0);
    if (digits == null) return null;
    return int.tryParse(digits);
  }

  Future<void> _loadAssetsInRoom(dynamic locationId) async {
    setState(() {
      isLoadingAssets = true;
      assetsInRoom = [];
    });
    try {
      final snapshot = await FirebaseService().getAssets();
      final targetId = locationId?.toString();
      final roomAssets = snapshot
          .where((a) => a.locationId?.toString() == targetId)
          .toList();
      setState(() {
        assetsInRoom = roomAssets
            .map(
              (a) => {
                'asset_id': a.assetId,
                'asset_type': a.assetType,
                'status': a.status,
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

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _equipmentSearchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getRoomsForFloor(int floor) {
    return locations.where((loc) {
      final f = _parseFloorInt(loc['floor']);
      return f == floor;
    }).toList();
  }

  Future<void> _pickImageFromGallery() async {
    if (_hasOpenReport || _isCheckingOpenReport) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        reportImages = [image.path];
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_hasOpenReport || _isCheckingOpenReport) return;
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        reportImages = [photo.path];
      });
    }
  }

  void _deleteImage(int index) {
    if (_hasOpenReport || _isCheckingOpenReport) return;
    setState(() {
      reportImages = [];
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

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.add_photo_alternate,
                color: Color(0xFFE44F5A),
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'เพิ่มรูปภาพหลักฐาน',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFF5593E4),
                  size: 30,
                ),
                title: const Text('ถ่ายรูป', style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF99CD60),
                  size: 30,
                ),
                title: const Text(
                  'เลือกจาก Gallery',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_isCheckingOpenReport) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กำลังตรวจสอบสถานะการแจ้งปัญหา...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_hasOpenReport) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('มีการแจ้งปัญหาแล้ว กรุณารอเจ้าหน้าที่ดำเนินการ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (currentEquipment == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกครุภัณฑ์ที่ต้องการแจ้งปัญหา'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อผู้แจ้ง'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกเหตุผลที่แจ้ง'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Call Firestore
    String assetId = (currentEquipment!['asset_id'] ?? currentEquipment!['id'])
        .toString();

    try {
      final hasOpen = await FirebaseService().hasOpenReportForAsset(assetId);
      if (hasOpen) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('มีการแจ้งปัญหาแล้ว กรุณารอเจ้าหน้าที่ดำเนินการ'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _hasOpenReport = true;
        });
        return;
      }
    } catch (_) {}

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE44F5A)),
      ),
    );

    // Upload images first if any
    String? uploadedImageUrl;
    if (reportImages.isNotEmpty) {
      // อัปโหลดรูปแรก (รองรับรูปเดียว)
      final firstImagePath = reportImages.first;
      final assetIdForUpload =
          (currentEquipment!['asset_id'] ?? currentEquipment!['id']).toString();
      uploadedImageUrl = await FirebaseService().uploadReportImage(
        File(firstImagePath),
        assetIdForUpload,
      );

      if (uploadedImageUrl == null) {
        if (!context.mounted) return;
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Get current user ID
    final user = FirebaseAuth.instance.currentUser;
    final String reporterId = user?.uid ?? '';

    final report = {
      'asset_id': assetId,
      if (currentEquipment?['asset_name']?.toString().trim().isNotEmpty == true)
        'asset_name': currentEquipment!['asset_name']?.toString().trim(),
      'reporter_name': _nameController.text.trim(),
      'reporter_id': reporterId, //
      //
      'report_remark': _reasonController.text.trim(),
      'report_image_url': uploadedImageUrl ?? '',
      'reported_at': FieldValue.serverTimestamp(), //
      'report_status': 1,
    };

    try {
      await FirebaseService().createReport(report, shouldCreateAuditLog: false);

      // Update asset status to 'ชำรุด' immediately after reporting
      await FirebaseService().updateAsset(assetId, {
        'asset_status': 2,
        'audited_at': FieldValue.serverTimestamp(),
        'reporter_name': _nameController.text.trim(),
        'issue_detail': _reasonController.text.trim(),
        'report_images':
            uploadedImageUrl != null && uploadedImageUrl.trim().isNotEmpty
            ? uploadedImageUrl.trim()
            : '',
        'repairer_id': null,
        'condemned_at': FieldValue.delete(),
      });

      if (!mounted) return;
      // Close Loading Dialog
      Navigator.pop(context);

      _handleReportSuccess(assetId, uploadedImageUrl, messenger, navigator);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      final msg = e.toString();
      if (msg.contains('DUPLICATE_OPEN_REPORT')) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('มีการแจ้งปัญหาแล้ว กรุณารอเจ้าหน้าที่ดำเนินการ'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleReportSuccess(
    String assetId,
    String? uploadedImageUrl,
    ScaffoldMessengerState messenger,
    NavigatorState navigator,
  ) {
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('ส่งแจ้งปัญหาสำเร็จ')),
          ],
        ),
        backgroundColor: const Color(0xFF99CD60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Return updated data to previous screen
    navigator.pop({
      'status': 'ชำรุด',
      'reporterName': _nameController.text.trim(),
      'reportReason': _reasonController.text.trim(),
      'issue_detail': _reasonController.text.trim(),
      'reportImages': (uploadedImageUrl != null) ? [uploadedImageUrl] : [],
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSelectionMode = widget.equipment == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      drawer: const AppDrawer(),
      body: isLoadingLocations
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE44F5A)),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: const Color(0xFFE44F5A),
                  leading: IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Color(0xFFE44F5A),
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
                    'แจ้งปัญหา/ขัดข้อง',
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
                          colors: [Color(0xFFE44F5A), Color(0xFFB81F3A)],
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
                                  : 'ขั้นตอนที่ 2: กรอกรายละเอียดและส่งแจ้งปัญหา',
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
                          const SizedBox(height: 10),
                        ],
                        if (currentEquipment != null) ...[
                          _buildEquipmentInfoCard(),
                          if (_isCheckingOpenReport || _hasOpenReport) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _isCheckingOpenReport
                                    ? Colors.blue.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isCheckingOpenReport
                                      ? Colors.blue.shade200
                                      : Colors.orange.shade200,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _isCheckingOpenReport
                                        ? Icons.hourglass_top_rounded
                                        : Icons.warning_amber_rounded,
                                    color: _isCheckingOpenReport
                                        ? Colors.blue
                                        : Colors.orange,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isCheckingOpenReport
                                              ? 'กำลังตรวจสอบการแจ้งปัญหา'
                                              : 'แจ้งซ้ำไม่ได้',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: _isCheckingOpenReport
                                                ? Colors.blue
                                                : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _isCheckingOpenReport
                                              ? 'กรุณารอสักครู่ ระบบกำลังตรวจสอบว่ามีคนแจ้งปัญหาแล้วหรือไม่'
                                              : ((_openReportReporterName !=
                                                            null &&
                                                        _openReportReporterName!
                                                            .trim()
                                                            .isNotEmpty)
                                                    ? 'ตอนนี้มี ${_openReportReporterName!.trim()} แจ้งปัญหาอยู่แล้ว\nกรุณารอเจ้าหน้าที่ดำเนินการ'
                                                    : 'มีคนแจ้งปัญหาอยู่แล้ว\nกรุณารอเจ้าหน้าที่ดำเนินการ'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            height: 1.35,
                                            color: _isCheckingOpenReport
                                                ? Colors.blue.shade800
                                                : Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildReportForm(),
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
              onPressed:
                  (currentEquipment == null ||
                      _hasOpenReport ||
                      _isCheckingOpenReport)
                  ? null
                  : _submitReport,
              icon: const Icon(Icons.send_rounded),
              label: Text(
                currentEquipment == null
                    ? 'เลือกครุภัณฑ์ก่อนจึงส่งได้'
                    : _hasOpenReport
                    ? 'มีคนแจ้งแล้ว'
                    : _isCheckingOpenReport
                    ? 'กำลังตรวจสอบ...'
                    : 'ส่งแจ้งปัญหา',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE44F5A),
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
              onPressed: (_hasOpenReport || _isCheckingOpenReport)
                  ? null
                  : _showImageSourceDialog,
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
                backgroundColor: const Color(0xFFE44F5A),
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

    final double listHeight = filteredAssets.isEmpty
        ? 0
        : ((filteredAssets.length * 52.0) + ((filteredAssets.length - 1) * 1.0))
              .clamp(52.0, 240.0);

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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFF2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_searching_rounded,
                  color: Color(0xFFE44F5A),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'เลือกห้องและครุภัณฑ์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                  color: Color(0xFFE44F5A),
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
                color: const Color(0xFFFFEFF2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE44F5A).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE44F5A)),
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
                  color: Color(0xFFE44F5A),
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
                const SizedBox(height: 8),
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
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SizedBox(
                      height: listHeight,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: filteredAssets.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final eq = filteredAssets[index];
                          final assetId = (eq['asset_id'] ?? eq['id'])
                              .toString();
                          final assetType = (eq['asset_type'] ?? eq['type'])
                              .toString();
                          final isSelected = selectedEquipmentId == assetId;
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            minVerticalPadding: 0,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tileColor: isSelected
                                ? const Color(0xFFFFEFF2)
                                : Colors.transparent,
                            title: Text(
                              assetId,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w700,
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
                              setState(() {
                                selectedEquipmentId = assetId;
                                currentEquipment = eq;
                              });

                              _refreshOpenReportState(showSnackbar: true);
                            },
                          );
                        },
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

  Widget _buildEquipmentInfoCard() {
    final assetId =
        currentEquipment?['asset_id'] ??
        currentEquipment?['id'] ??
        'ไม่ระบุรหัส';
    String assetType =
        currentEquipment?['asset_type'] ?? currentEquipment?['type'] ?? '';
    // Map ID to Name if possible
    if (categoryMap.isNotEmpty && categoryMap.containsKey(assetType)) {
      assetType = categoryMap[assetType]!;
    }
    final roomDisplayName = selectedRoom ?? widget.roomName ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE5E8), Color(0xFFFFF0F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE44F5A).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE44F5A).withValues(alpha: 0.15),
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
                  color: const Color(0xFFE44F5A).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.computer,
              color: Color(0xFFE44F5A),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assetId.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$assetType • $roomDisplayName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
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

  Widget _buildReportForm() {
    return Column(
      children: [
        // ชื่อผู้แจ้ง
        _buildFormCard(
          icon: Icons.person,
          title: 'ชื่อผู้แจ้ง',
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
                  color: Color(0xFFE44F5A),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // เหตุผลที่แจ้ง
        _buildFormCard(
          icon: Icons.description,
          title: 'เหตุผลที่แจ้ง',
          required: true,
          child: TextField(
            controller: _reasonController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'อธิบายปัญหาที่พบ เช่น หน้าจอเป็นเส้น, เปิดไม่ติด, คีย์บอร์ดพิมพ์ไม่ได้',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE44F5A),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // รูปภาพหลักฐาน
        _buildImageSection(),
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
              Icon(icon, color: const Color(0xFFE44F5A), size: 24),
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
                  style: TextStyle(color: Color(0xFFE44F5A), fontSize: 18),
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
                  Icon(Icons.photo_camera, color: Color(0xFFE44F5A), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'รูปภาพหลักฐาน',
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
                  color: const Color(0xFFE44F5A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${reportImages.length} รูป',
                  style: const TextStyle(
                    color: Color(0xFFE44F5A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          reportImages.isEmpty
              ? _buildEmptyImageState()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _openLocalImagePreview(reportImages.first),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 280,
                          color: Colors.grey.shade100,
                          child: Image.file(
                            File(reportImages.first),
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
                            foregroundColor: const Color(0xFFE44F5A),
                            side: BorderSide(
                              color: const Color(
                                0xFFE44F5A,
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
          colors: [Color(0xFFE44F5A), Color(0xFFD43F50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE44F5A).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _submitReport,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.send, color: Colors.white, size: 26),
                SizedBox(width: 14),
                Text(
                  'ส่งแจ้งปัญหา',
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
              'กรุณาเลือกครุภัณฑ์เพื่อแจ้งปัญหา',
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
}
