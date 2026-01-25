import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

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
  int? selectedRoomId;
  String? selectedEquipmentId;
  Map<String, dynamic>? currentEquipment;

  // Form State
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  List<String> inspectorImages = [];
  String selectedStatus = 'ปกติ';

  // API Data
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> assetsInRoom = [];
  bool isLoadingLocations = true;
  bool isLoadingAssets = false;

  final List<Map<String, dynamic>> statusList = [
    {'name': 'ปกติ', 'color': Color(0xFF99CD60), 'icon': Icons.check_circle},
    {'name': 'ชำรุด', 'color': Color(0xFFE44F5A), 'icon': Icons.cancel},
    {
      'name': 'อยู่ระหว่างซ่อม',
      'color': Color(0xFFFECC52),
      'icon': Icons.build_circle,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.equipment != null) {
      currentEquipment = widget.equipment;
      selectedRoom = widget.roomName;
      selectedEquipmentId =
          widget.equipment!['asset_id'] ?? widget.equipment!['id'];
      selectedStatus = widget.equipment!['status'] ?? 'ปกติ';
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
      setState(() => inspectorImages.add(image.path));
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() => inspectorImages.add(photo.path));
    }
  }

  void _deleteImage(int index) {
    setState(() => inspectorImages.removeAt(index));
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
                color: Color(0xFF5593E4),
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'เพิ่มรูปภาพ',
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

    if (_nameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อผู้ตรวจ'),
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
        child: CircularProgressIndicator(color: Color(0xFF5593E4)),
      ),
    );

    // Get checker_id from current user
    final currentUser = ApiService().currentUser;
    final checkerId = currentUser?['user_id'];

    if (checkerId == null) {
      if (!context.mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลผู้ใช้ กรุณา login ใหม่'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final assetId = (currentEquipment!['asset_id'] ?? currentEquipment!['id'])
        .toString();

    // Call API
    final result = await ApiService().createCheckLog(
      assetId: assetId,
      checkerId: checkerId,
      resultStatus: selectedStatus,
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
    );

    // Also update asset status and checker name explicitly to ensure Sync
    if (result['success']) {
      try {
        final Map<String, dynamic> updateData = Map.from(currentEquipment!);
        updateData['status'] = selectedStatus;
        updateData['inspectorName'] = _nameController.text.trim();
        // Ensure type compatibility
        if (updateData['type'] == null && updateData['asset_type'] != null) {
          updateData['type'] = updateData['asset_type'];
        }

        await ApiService().updateAsset(assetId, updateData);
      } catch (e) {
        debugPrint('Error updating asset details: $e');
        // Continue event if update fails, as log is created
      }
    }

    // Close Loading
    if (!mounted) return;
    Navigator.pop(context);

    if (result['success']) {
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

      // Return result
      navigator.pop({
        'status': selectedStatus,
        'checkerName': _nameController.text.trim(),
        'remark': _remarkController.text.trim(),
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
        backgroundColor: const Color(0xFF5593E4),
        elevation: 0,
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
        centerTitle: true,
        title: const Text(
          'ตรวจสอบอุปกรณ์',
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
              child: CircularProgressIndicator(color: Color(0xFF5593E4)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (isSelectionMode) ...[
                  _buildSelectionSection(),
                  const SizedBox(height: 25),
                ],

                if (currentEquipment != null) ...[
                  _buildEquipmentInfoCard(),
                  const SizedBox(height: 25),
                  if (currentEquipment!['reporter_name'] != null ||
                      currentEquipment!['reporterName'] != null)
                    _buildReporterInfo(),
                  const SizedBox(height: 25),
                  _buildInspectionForm(),
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
        gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5593E4), Color(0xFF3D7BC4)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5593E4).withValues(alpha: 0.3),
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
                  color: Color(0xFF5593E4),
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
                            ? 'ไม่พบครุภัณฑ์'
                            : 'เลือกครุภัณฑ์',
                      ),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF5593E4),
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
                                selectedStatus =
                                    currentEquipment!['status'] ?? 'ปกติ';
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
    final status = currentEquipment?['status'] ?? 'ปกติ';
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
                    onTap: () =>
                        setState(() => selectedStatus = status['name']),
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

        // หมายเหตุ
        _buildFormCard(
          icon: Icons.note_alt,
          title: 'หมายเหตุ',
          required: false,
          child: TextField(
            controller: _remarkController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'เช่น พบฝุ่นเยอะ, ปลั๊กหลวม (ถ้ามี)',
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

        // รูปภาพ
        _buildImageSection(),
        const SizedBox(height: 30),

        // ปุ่มบันทึก
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
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: inspectorImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == inspectorImages.length) {
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
              backgroundColor: const Color(0xFF5593E4),
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
