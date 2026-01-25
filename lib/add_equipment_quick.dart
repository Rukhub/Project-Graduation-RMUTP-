import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class AddEquipmentQuickScreen extends StatefulWidget {
  const AddEquipmentQuickScreen({super.key});

  @override
  State<AddEquipmentQuickScreen> createState() =>
      _AddEquipmentQuickScreenState();
}

class _AddEquipmentQuickScreenState extends State<AddEquipmentQuickScreen> {
  // State
  int selectedFloor = 1;
  List<Map<String, dynamic>> locations = [];
  bool isLoadingLocations = true;

  // Equipment Types
  final List<Map<String, dynamic>> equipmentTypes = [
    {'name': 'หน้าจอ', 'icon': Icons.monitor, 'color': Color(0xFF5593E4)},
    {'name': 'เคสคอม', 'icon': Icons.storage, 'color': Color(0xFF99CD60)},
    {'name': 'เมาส์', 'icon': Icons.mouse, 'color': Color(0xFFFECC52)},
    {'name': 'คีย์บอร์ด', 'icon': Icons.keyboard, 'color': Color(0xFFE44F5A)},
    {'name': 'เครื่องพิมพ์', 'icon': Icons.print, 'color': Color(0xFF9A2C2C)},
    {
      'name': 'โปรเจคเตอร์',
      'icon': Icons.slideshow,
      'color': Color(0xFF7B68EE),
    },
  ];

  @override
  void initState() {
    super.initState();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถโหลดข้อมูลห้องได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> getRoomsForFloor(int floor) {
    return locations.where((loc) {
      final floorStr = loc['floor']?.toString() ?? '';
      return floorStr.contains('$floor') || floorStr == 'ชั้น $floor';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roomsInFloor = getRoomsForFloor(selectedFloor);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        elevation: 0,
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Color(0xFF9A2C2C),
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'เพิ่มอุปกรณ์',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        toolbarHeight: 80,
      ),
      body: isLoadingLocations
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF9A2C2C)),
            )
          : Column(
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9A2C2C), Color(0xFF7A2222)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เลือกห้องที่ต้องการเพิ่มอุปกรณ์',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Floor Selector
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButton<int>(
                          value: selectedFloor,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF9A2C2C),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          items: List.generate(6, (index) {
                            int floor = index + 1;
                            int roomCount = getRoomsForFloor(floor).length;
                            return DropdownMenuItem(
                              value: floor,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF9A2C2C,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.layers,
                                      color: Color(0xFF9A2C2C),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'ชั้น $floor',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF9A2C2C,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$roomCount ห้อง',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9A2C2C),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          onChanged: (value) {
                            setState(() => selectedFloor = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Rooms List
                Expanded(
                  child: roomsInFloor.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadLocations,
                          color: const Color(0xFF9A2C2C),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: roomsInFloor.length,
                            itemBuilder: (context, index) {
                              final room = roomsInFloor[index];
                              return _buildRoomCard(room);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final roomName = room['room_name'] ?? 'ไม่ระบุชื่อ';
    final locationId = room['location_id'] ?? room['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showAddEquipmentDialog(roomName, locationId),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9A2C2C), Color(0xFF7A2222)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9A2C2C).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.meeting_room,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ชั้น $selectedFloor',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF99CD60).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_circle,
                    color: Color(0xFF99CD60),
                    size: 28,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.meeting_room_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ไม่มีห้องในชั้นนี้',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'กรุณาเลือกชั้นอื่น',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showAddEquipmentDialog(String roomName, int locationId) {
    final TextEditingController assetIdController = TextEditingController();
    final TextEditingController brandModelController = TextEditingController();
    String selectedType = equipmentTypes.first['name'] as String;
    bool isSubmitting = false;

    // Image upload state
    File? selectedImage;
    final ImagePicker picker = ImagePicker();
    bool isUploadingImage = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF9A2C2C),
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'เพิ่มครุภัณฑ์ใหม่',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF9A2C2C).withValues(alpha: 0.15),
                          Color(0xFF9A2C2C).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF9A2C2C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.meeting_room,
                          size: 18,
                          color: Color(0xFF9A2C2C),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$roomName • ชั้น $selectedFloor',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9A2C2C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // ⭐ แก้: ให้ขยายเต็มแนวกว้างโดยไม่ต้องระบุ width
                  children: [
                    // Asset ID
                    TextField(
                      controller: assetIdController,
                      decoration: InputDecoration(
                        labelText: 'รหัสครุภัณฑ์ *',
                        hintText: 'เช่น 140695-25',
                        prefixIcon: const Icon(
                          Icons.qr_code,
                          color: Color(0xFF9A2C2C),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF9A2C2C),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Brand/Model
                    TextField(
                      controller: brandModelController,
                      decoration: InputDecoration(
                        labelText: 'ยี่ห้อ/รุ่น *',
                        hintText: 'เช่น Dell OptiPlex 7070',
                        prefixIcon: const Icon(
                          Icons.business,
                          color: Color(0xFF9A2C2C),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF9A2C2C),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Equipment Type
                    Text(
                      'ประเภท *',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey.shade50,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF9A2C2C),
                        ),
                        items: equipmentTypes.map((type) {
                          return DropdownMenuItem(
                            value: type['name'] as String,
                            child: Row(
                              children: [
                                Icon(
                                  type['icon'] as IconData,
                                  size: 22,
                                  color: type['color'] as Color,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  type['name'] as String,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedType = value!);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Image Upload Section
                    Text(
                      'รูปภาพครุภัณฑ์',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: isSubmitting || isUploadingImage
                          ? null
                          : () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.camera_alt,
                                          color: Color(0xFF5593E4),
                                        ),
                                        title: const Text('ถ่ายรูป'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final XFile? image = await picker
                                              .pickImage(
                                                source: ImageSource.camera,
                                                maxWidth: 1024,
                                                maxHeight: 1024,
                                                imageQuality: 85,
                                              );
                                          if (image != null) {
                                            setDialogState(
                                              () => selectedImage = File(
                                                image.path,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo_library,
                                          color: Color(0xFF99CD60),
                                        ),
                                        title: const Text('เลือกจาก Gallery'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final XFile? image = await picker
                                              .pickImage(
                                                source: ImageSource.gallery,
                                                maxWidth: 1024,
                                                maxHeight: 1024,
                                                imageQuality: 85,
                                              );
                                          if (image != null) {
                                            setDialogState(
                                              () => selectedImage = File(
                                                image.path,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                      child: Container(
                        height: 180,
                        // ตัด width: double.infinity ออก เพราะใช้ stretch จาก Column แล้ว
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey.shade50,
                        ),
                        child: selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'เพิ่มรูปภาพครุภัณฑ์',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '(ไม่บังคับ)',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        20,
                                      ), // Match parent border radius
                                      child: Image.file(
                                        selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setDialogState(
                                        () => selectedImage = null,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          // Validation
                          if (assetIdController.text.trim().isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('กรุณากรอกรหัสครุภัณฑ์'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          if (brandModelController.text.trim().isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('กรุณากรอกยี่ห้อ/รุ่น'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final assetId = assetIdController.text.trim();
                            // Get current user for created_by
                            final currentUser = ApiService().currentUser;
                            String createdBy = '';
                            if (currentUser != null) {
                              createdBy =
                                  currentUser['fullname'] ??
                                  currentUser['username'] ??
                                  '';
                            }

                            // Upload image first if selected
                            String? imageUrl;
                            if (selectedImage != null) {
                              setDialogState(() => isUploadingImage = true);
                              imageUrl = await ApiService().uploadImage(
                                selectedImage!,
                              );
                              setDialogState(() => isUploadingImage = false);

                              if (imageUrl == null) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                setDialogState(() => isSubmitting = false);
                                return;
                              }
                            }

                            final result = await ApiService().addAsset({
                              'asset_id': assetId,
                              'type': selectedType,
                              'brand_model': brandModelController.text.trim(),
                              'location_id': locationId,
                              'status': 'ปกติ',
                              'images': imageUrl != null ? [imageUrl] : [],
                              'created_by': createdBy,
                              'inspectorName':
                                  createdBy, // Set inspector as creator initially
                            });

                            if (!context.mounted) return;

                            Navigator.pop(dialogContext);

                            if (result['success'] == true) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('เพิ่ม $assetId สำเร็จ'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF99CD60),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              navigator.pop(); // กลับหน้าเมนู
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result['message'] ?? 'เกิดข้อผิดพลาด',
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'เพิ่ม',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
