import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

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
  int? selectedRoomId;
  String? selectedEquipmentId;
  Map<String, dynamic>? currentEquipment;

  // Form State
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  List<String> reportImages = [];

  // API Data
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> assetsInRoom = [];
  bool isLoadingLocations = true;
  bool isLoadingAssets = false;

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
  }

  Future<void> _loadLocations() async {
    setState(() => isLoadingLocations = true);
    try {
      final data = await ApiService().getLocations();
      setState(() {
        locations = data;
        isLoadingLocations = false;
      });
    } catch (e) {
      debugPrint('Error loading locations: $e');
      setState(() => isLoadingLocations = false);
    }
  }

  Future<void> _loadAssetsInRoom(int locationId) async {
    setState(() => isLoadingAssets = true);
    try {
      final data = await ApiService().getAssetsByLocation(locationId);
      setState(() {
        assetsInRoom = data;
        isLoadingAssets = false;
      });
    } catch (e) {
      debugPrint('Error loading assets: $e');
      setState(() => isLoadingAssets = false);
    }
  }

  List<Map<String, dynamic>> getRoomsForFloor(int floor) {
    return locations.where((loc) {
      final floorStr = loc['floor']?.toString() ?? '';
      return floorStr.contains('$floor') || floorStr == 'ชั้น $floor';
    }).toList();
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        reportImages.add(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        reportImages.add(photo.path);
      });
    }
  }

  void _deleteImage(int index) {
    setState(() {
      reportImages.removeAt(index);
    });
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
      debugPrint('�� กำลังอัปโหลดรูปภาพ ${reportImages.length} รูป');

      // อัปโหลดรูปแรก (โบรับแค่ image_url เดียว)
      final firstImagePath = reportImages.first;
      uploadedImageUrl = await ApiService().uploadImage(File(firstImagePath));

      if (uploadedImageUrl == null) {
        debugPrint('❌ อัปโหลดรูปภาพไม่สำเร็จ');
        if (!context.mounted) return;
        navigator.pop(); // ปิด loading

        messenger.showSnackBar(
          const SnackBar(
            content: Text('อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Call API
    String assetId = (currentEquipment!['asset_id'] ?? currentEquipment!['id'])
        .toString();

    final result = await ApiService().reportProblem(
      assetId,
      _nameController.text.trim(),
      _reasonController.text.trim(),
      imageUrl: uploadedImageUrl, // ส่ง URL ที่อัปโหลดแล้ว
    );

    // Sync reporter info AND Image to Asset record as well
    if (result['success'] == true) {
      try {
        final Map<String, dynamic> updateData = Map.from(currentEquipment!);
        updateData['status'] = 'ชำรุด';
        updateData['reporter_name'] = _nameController.text.trim();
        updateData['issue_detail'] = _reasonController.text.trim();

        // ⭐ Bo's instruction: DON'T overwrite asset.image_url with report image.
        // We sync report details and optionally 'report_images' if Bo added that column.
        updateData['report_images'] = uploadedImageUrl ?? '';

        /*
        if (uploadedImageUrl != null) {
          updateData['image_url'] = uploadedImageUrl;
        }
        */

        // Ensure type compatibility
        if (updateData['type'] == null && updateData['asset_type'] != null) {
          updateData['type'] = updateData['asset_type'];
        }

        await ApiService().updateAsset(assetId, updateData);
      } catch (e) {
        debugPrint('Error syncing reporter info to asset: $e');
        // Non-fatal, continue
      }
    }

    // Close Loading
    if (!context.mounted) return;
    navigator.pop();

    if (result['success']) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'เกิดข้อผิดพลาด'),
          backgroundColor: const Color(0xFFE44F5A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSelectionMode = widget.equipment == null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE44F5A),
        elevation: 0,
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
        centerTitle: true,
        title: const Text(
          'แจ้งปัญหา/ขัดข้อง',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        toolbarHeight: 80,
      ),
      body: isLoadingLocations
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE44F5A)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ส่วนเลือกครุภัณฑ์
                if (isSelectionMode) ...[
                  _buildSelectionSection(),
                  const SizedBox(height: 25),
                ],

                // แสดงฟอร์มเมื่อมีข้อมูลครุภัณฑ์แล้ว
                if (currentEquipment != null) ...[
                  _buildEquipmentInfoCard(),
                  const SizedBox(height: 25),
                  _buildReportForm(),
                ] else if (isSelectionMode) ...[
                  _buildEmptyState(),
                ],
              ],
            ),
    );
  }

  Widget _buildSelectionSection() {
    final roomsInFloor = getRoomsForFloor(selectedFloor);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE44F5A), Color(0xFFD43F50)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE44F5A).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Text(
                'ค้นหาครุภัณฑ์',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

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
                  color: Color(0xFFE44F5A),
                ),
                items: List.generate(6, (i) => i + 1).map((floor) {
                  return DropdownMenuItem(
                    value: floor,
                    child: Text(
                      'ชั้น $floor',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFloor = value!;
                    selectedRoom = null;
                    selectedRoomId = null;
                    selectedEquipmentId = null;
                    currentEquipment = null;
                    assetsInRoom = [];
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // เลือกห้อง
          _buildDropdownLabel('ห้อง'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _buildDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRoom,
                hint: const Text('เลือกห้อง'),
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
                onChanged: (value) {
                  final room = roomsInFloor.firstWhere(
                    (r) => r['room_name'] == value,
                  );
                  setState(() {
                    selectedRoom = value;
                    selectedRoomId = room['location_id'] ?? room['id'];
                    selectedEquipmentId = null;
                    currentEquipment = null;
                  });
                  if (selectedRoomId != null) {
                    _loadAssetsInRoom(selectedRoomId!);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // เลือกครุภัณฑ์
          _buildDropdownLabel('ครุภัณฑ์'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _buildDropdownDecoration(),
            child: isLoadingAssets
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedEquipmentId,
                      hint: Text(
                        assetsInRoom.isEmpty
                            ? 'ไม่พบครุภัณฑ์ในห้องนี้'
                            : 'เลือกครุภัณฑ์',
                      ),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFFE44F5A),
                      ),
                      items: assetsInRoom.map((eq) {
                        final assetId = eq['asset_id'] ?? eq['id'];
                        return DropdownMenuItem(
                          value: assetId.toString(),
                          child: Text(
                            '${eq['asset_type'] ?? eq['type']} - $assetId',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: assetsInRoom.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                selectedEquipmentId = value;
                                currentEquipment = assetsInRoom.firstWhere(
                                  (e) =>
                                      (e['asset_id'] ?? e['id']).toString() ==
                                      value,
                                );
                              });
                            },
                    ),
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
    final assetType =
        currentEquipment?['asset_type'] ?? currentEquipment?['type'] ?? '';
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
                    Text(
                      '$assetType • $roomDisplayName',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
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
        const SizedBox(height: 30),

        // ปุ่มส่งแจ้งปัญหา
        _buildSubmitButton(),
        const SizedBox(height: 30),
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
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: reportImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == reportImages.length) {
                      return _buildAddImageButton();
                    }
                    return _buildImageCard(index);
                  },
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

  Widget _buildEmptyImageState() {
    return Container(
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Column(
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
              backgroundColor: const Color(0xFFE44F5A),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
      onTap: _showImageSourceDialog,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE44F5A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE44F5A).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.add_photo_alternate,
          color: Color(0xFFE44F5A),
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
              image: FileImage(File(reportImages[index])),
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
