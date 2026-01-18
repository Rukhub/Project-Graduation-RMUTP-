import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'data_service.dart';

class InspectEquipmentScreen extends StatefulWidget {
  final Map<String, dynamic>? equipment;
  final String? roomName;

  const InspectEquipmentScreen({
    super.key,
    this.equipment,
    this.roomName,
  });

  @override
  State<InspectEquipmentScreen> createState() => _InspectEquipmentScreenState();
}

class _InspectEquipmentScreenState extends State<InspectEquipmentScreen> {
  // Selection State
  int selectedFloor = 1;
  String? selectedRoom;
  String? selectedEquipmentId;
  Map<String, dynamic>? currentEquipment;
  String? currentStatus; // สถานะปัจจุบันของครุภัณฑ์ที่เลือก

  // Form State
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  List<String> inspectorImages = [];
  String selectedStatus = 'ปกติ';

  final DataService _dataService = DataService();

  final List<Map<String, dynamic>> statusList = [
    {'name': 'ปกติ', 'color': Colors.green, 'icon': Icons.check_circle},
    {'name': 'อยู่ระหว่างซ่อม', 'color': Colors.orange, 'icon': Icons.build_circle},
    {'name': 'ชำรุด', 'color': const Color(0xFFE44F5A), 'icon': Icons.cancel},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.equipment != null) {
      currentEquipment = widget.equipment;
      selectedRoom = widget.roomName;
      selectedEquipmentId = widget.equipment!['id'];
      currentStatus = widget.equipment!['status'];
      selectedStatus = currentStatus ?? 'ปกติ'; // Default to current status
      
      if (widget.equipment!['inspectorName'] != null) {
        _nameController.text = widget.equipment!['inspectorName'];
      }
    }
    
    // Autofill inspector name if empty
    if (_nameController.text.isEmpty) {
        final currentUser = ApiService().currentUser;
        if (currentUser != null && currentUser['fullname'] != null) {
          _nameController.text = currentUser['fullname'];
        }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() { inspectorImages.add(image.path); });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() { inspectorImages.add(photo.path); });
    }
  }

  void _deleteImage(int index) {
    setState(() { inspectorImages.removeAt(index); });
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.add_photo_alternate, color: Color(0xFF5593E4), size: 28),
              SizedBox(width: 10),
              Text('เพิ่มรูปภาพ', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF5593E4), size: 30),
                title: const Text('ถ่ายรูป', style: TextStyle(fontSize: 16)),
                onTap: () { Navigator.pop(context); _takePhoto(); },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF99CD60), size: 30),
                title: const Text('เลือกจาก Gallery', style: TextStyle(fontSize: 16)),
                onTap: () { Navigator.pop(context); _pickImageFromGallery(); },
              ),
            ],
          ),
        );
      },
    );
  }

  void _submitInspection() {
    if (currentEquipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกครุภัณฑ์')));
      return;
    }
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อผู้ตรวจ')));
      return;
    }

    // สร้าง Map ข้อมูลที่จะส่งกลับ/อัปเดต
    Map<String, dynamic> result = {
      'status': selectedStatus,
      'inspectorName': _nameController.text,
      'inspectorImages': inspectorImages,
      'id': currentEquipment!['id'],
    };

    if (selectedStatus == 'ปกติ') {
      result['reporterName'] = null;
      result['reportReason'] = null;
      result['reportImages'] = [];
    }

    // เรียก API อัปเดตข้อมูลใน Database จริง
    if (currentEquipment!['id'] != null) {
      // Prepare data for API (Backend expects snake_case mostly)
      Map<String, dynamic> apiData = {
        'asset_id': currentEquipment!['asset_id'] ?? currentEquipment!['id'], // Prefer asset_id
        'type': currentEquipment!['type'] ?? currentEquipment!['asset_type'],
        'brand_model': currentEquipment!['brand_model'] ?? '',
        'location_id': currentEquipment!['location_id'] ?? 0,
        'status': selectedStatus,
        'inspectorName': _nameController.text,
        'images': inspectorImages, // API service handles image_url from list
      };

      // Call API (Fire and forget or await? Better await to show loading/error if needed, but for now just call)
      // Note: `id` for updateAsset is the database ID (int/string)
      ApiService().updateAsset(currentEquipment!['id'].toString(), apiData).then((response) {
        if (!response['success']) {
          debugPrint('❌ Failed to update asset in DB: ${response['message']}');
        } else {
          debugPrint('✅ Asset updated in DB successfully');
        }
      });
    }

    // บันทึกลง Global Data ผ่าน DataService (เพื่อให้ App รู้ทันที)
    Map<String, dynamic> updatedItem = Map.from(currentEquipment!);
    updatedItem.addAll(result);
    // ต้องระบุ RoomName
    String effectiveRoomName = selectedRoom ?? widget.roomName ?? '';
    if (effectiveRoomName.isNotEmpty) {
       _dataService.updateEquipment(effectiveRoomName, updatedItem);
    }
    
    // ส่งข้อมูลกลับ
    Navigator.pop(context, result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(selectedStatus == 'ปกติ' ? 'ตรวจสอบเสร็จสิ้น อุปกรณ์พร้อมใช้งาน' : 'บันทึกการตรวจสอบ สถานะ: $selectedStatus'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSelectionMode = widget.equipment == null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5593E4),
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF5593E4)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'ตรวจสอบอุปกรณ์',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        toolbarHeight: 70,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isSelectionMode) ...[
            _buildSelectionSection(),
            const SizedBox(height: 25),
          ],
          
          if (currentEquipment != null) ...[
            _buildEquipmentInfoCard(),
            const SizedBox(height: 25),
            if (currentEquipment!['reporterName'] != null) _buildReporterInfo(),
            const SizedBox(height: 25),
            _buildInspectionForm(),
          ] else if (isSelectionMode) ...[
             Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.search, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 15),
                  Text(
                    'กรุณาเลือกครุภัณฑ์เพื่อตรวจสอบ',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSelectionSection() {
     var floorRooms = _dataService.floorRooms;
     List<String> rooms = floorRooms[selectedFloor] ?? [];
     List<Map<String, dynamic>> equipments = selectedRoom != null 
        ? _dataService.getEquipmentsInRoom(selectedRoom!) 
        : [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.search, color: Colors.blue.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'ค้นหาครุภัณฑ์ที่ต้องตรวจสอบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildDropdownLabel('ชั้น'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: _buildDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedFloor,
                isExpanded: true,
                items: floorRooms.keys.map((floor) {
                  return DropdownMenuItem(
                    value: floor,
                    child: Text('ชั้น $floor'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFloor = value!;
                    selectedRoom = null;
                    selectedEquipmentId = null;
                    currentEquipment = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 15),

          _buildDropdownLabel('ห้อง'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: _buildDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRoom,
                hint: const Text('เลือกห้อง'),
                isExpanded: true,
                items: rooms.map((room) {
                  return DropdownMenuItem(
                    value: room,
                    child: Text(room),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRoom = value;
                    selectedEquipmentId = null;
                    currentEquipment = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 15),

          _buildDropdownLabel('ครุภัณฑ์'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: _buildDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedEquipmentId,
                hint: Text(equipments.isEmpty ? 'ไม่พบครุภัณฑ์' : 'เลือกครุภัณฑ์'),
                isExpanded: true,
                items: equipments.map((eq) {
                  return DropdownMenuItem(
                    value: eq['id'] as String,
                    child: Text(
                      '${eq['type']} - ${eq['id']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: equipments.isEmpty ? null : (value) {
                  setState(() {
                    selectedEquipmentId = value;
                    currentEquipment = equipments.firstWhere((e) => e['id'] == value);
                    currentStatus = currentEquipment!['status'];
                    selectedStatus = currentStatus!;
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
    Color statusColor = currentStatus == 'ปกติ' ? Colors.green : (currentStatus == 'ชำรุด' ? const Color(0xFFE44F5A) : Colors.orange);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.blue.withValues(alpha:0.2), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.computer, color: Color(0xFF5593E4), size: 32),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentEquipment?['asset_id'] ?? currentEquipment?['id'] ?? 'ไม่ระบุรหัส',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentEquipment?['type'] ?? ''} • ${selectedRoom ?? widget.roomName ?? ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
             decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
             child: Text(currentStatus ?? 'ปกติ', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReporterInfo() {
     return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem, color: Colors.red.shade600, size: 24),
              const SizedBox(width: 10),
              const Text('ปัญหาที่แจ้ง', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text('ผู้แจ้ง: ${currentEquipment!['reporterName']}', style: const TextStyle(fontSize: 14)),
            ],
          ),
           const SizedBox(height: 5),
           if (currentEquipment!['reportReason'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text('รายละเอียด: ${currentEquipment!['reportReason']}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            ),
        ],
      ),
    );
  }

  Widget _buildInspectionForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.person_search, color: Color(0xFF5593E4), size: 24),
                  SizedBox(width: 10),
                  Text('ชื่อผู้ตรวจ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'กรอกชื่อ-นามสกุล',
                  prefixIcon: Icon(Icons.edit, color: Colors.grey.shade500),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                   focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF5593E4), width: 2)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.assignment_turned_in, color: Color(0xFF5593E4), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'ผลการตรวจสอบ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ...statusList.map((status) {
                bool isSelected = selectedStatus == status['name'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedStatus = status['name'];
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (status['color'] as Color).withValues(alpha:0.15) 
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? status['color'] as Color : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? status['color'] as Color : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            status['icon'] as IconData,
                            color: status['color'] as Color,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            status['name'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: const [Icon(Icons.photo_camera, color: Color(0xFF5593E4), size: 24), SizedBox(width: 10), Text('รูปภาพการตรวจสอบ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF5593E4).withValues(alpha:0.1), borderRadius: BorderRadius.circular(15)), child: Text('${inspectorImages.length} รูป', style: const TextStyle(color: Color(0xFF5593E4), fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
              const SizedBox(height: 15),
              inspectorImages.isEmpty 
                ? _buildEmptyImageState() 
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: inspectorImages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == inspectorImages.length) return _buildAddImageButton();
                      return _buildImageCard(index);
                    },
                  ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        Container(
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5593E4), Color(0xFF3D7BC4)]), borderRadius: BorderRadius.circular(16)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _submitInspection,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.verified, color: Colors.white, size: 24), SizedBox(width: 12), Text('บันทึกการตรวจสอบ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDropdownLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)));
  }

  BoxDecoration _buildDropdownDecoration() {
    return BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4))]);
  }

  Widget _buildEmptyImageState() {
     return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200, width: 2)),
      child: Column(
        children: [
          Icon(Icons.photo_camera, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('ยังไม่มีรูปภาพ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 20),
            label: const Text('เพิ่มรูปภาพ', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5593E4)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(onTap: _showImageSourceDialog, child: Container(decoration: BoxDecoration(color: const Color(0xFF5593E4).withValues(alpha:0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF5593E4).withValues(alpha:0.3), width: 2)), child: const Icon(Icons.add_photo_alternate, color: Color(0xFF5593E4), size: 35)));
  }

  Widget _buildImageCard(int index) {
    return Stack(children: [Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: FileImage(File(inspectorImages[index])), fit: BoxFit.cover))), Positioned(top: 5, right: 5, child: InkWell(onTap: () => _deleteImage(index), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.close, color: Colors.white, size: 16))))]);
  }
}
