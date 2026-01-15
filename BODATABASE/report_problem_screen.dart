import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'data_service.dart';

class ReportProblemScreen extends StatefulWidget {
  // รับข้อมูลแบบ Optional เพราะถ้าเข้ามาจากหน้า Menu จะยังไม่มีข้อมูล
  final Map<String, dynamic>? equipment;
  final String? roomName;

  const ReportProblemScreen({
    super.key,
    this.equipment,
    this.roomName,
  });

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  // State สำหรับการเลือกครุภัณฑ์
  int selectedFloor = 1;
  String? selectedRoom;
  String? selectedEquipmentId;
  Map<String, dynamic>? currentEquipment;

  // Form State
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  List<String> reportImages = [];

  // DataService
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    // ถ้ามีข้อมูลส่งมา (จากหน้า Detail) ให้ใช้เลย
    if (widget.equipment != null && widget.roomName != null) {
      currentEquipment = widget.equipment;
      selectedRoom = widget.roomName;
      selectedEquipmentId = widget.equipment!['id'];
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.add_photo_alternate, color: Color(0xFF9A2C2C), size: 28),
              SizedBox(width: 10),
              Text('เพิ่มรูปภาพหลักฐาน', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF5593E4), size: 30),
                title: const Text('ถ่ายรูป', style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF99CD60), size: 30),
                title: const Text('เลือกจาก Gallery', style: TextStyle(fontSize: 16)),
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

  void _submitReport() {
    if (currentEquipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกครุภัณฑ์ที่ต้องการแจ้งปัญหา')),
      );
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อผู้แจ้ง')),
      );
      return;
    }

    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกเหตุผลที่แจ้ง')),
      );
      return;
    }

    // สร้าง Map ข้อมูลที่จะส่งกลับ
    Map<String, dynamic> result = {
      'status': 'ชำรุด',
      'reporterName': _nameController.text,
      'reportReason': _reasonController.text,
      'reportImages': reportImages,
      // ส่ง ID กลับไปด้วยเผื่อเอาไปใช้ค้นหา
      'id': currentEquipment!['id'],
    };
    
    // บันทึกลง Global Data ผ่าน DataService
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
      const SnackBar(
        content: Text('ส่งแจ้งปัญหาสำเร็จ'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่มีการส่งข้อมูลมาแต่แรก ให้แสดงส่วนเลือกครุภัณฑ์
    bool isSelectionMode = widget.equipment == null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red.shade600,
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.red),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'แจ้งปัญหา/ขัดข้อง',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        toolbarHeight: 70,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ส่วนเลือกครุภัณฑ์ (แสดงเฉพาะเมื่อไม่มีข้อมูลส่งมา)
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
             // Empty State เมื่อยังไม่เลือก
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.search, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 15),
                  Text(
                    'กรุณาเลือกครุภัณฑ์เพื่อแจ้งปัญหา',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
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
            color: Colors.black.withOpacity(0.05),
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.search, color: Colors.red.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'ค้นหาครุภัณฑ์',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // เลือกชั้น
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

          // เลือกห้อง
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

          // เลือกครุภัณฑ์
          _buildDropdownLabel('ครุภัณฑ์'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: _buildDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedEquipmentId,
                hint: Text(equipments.isEmpty ? 'ไม่พบครุภัณฑ์ในห้องนี้' : 'เลือกครุภัณฑ์'),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.computer, color: Colors.red.shade600, size: 32),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentEquipment?['id'] ?? 'ไม่ระบุรหัส',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentEquipment?['type'] ?? ''} • ${selectedRoom ?? widget.roomName ?? ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
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
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                  Icon(Icons.person, color: Colors.red.shade600, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'ชื่อผู้แจ้ง',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'กรอกชื่อ-นามสกุล',
                  prefixIcon: Icon(Icons.edit, color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // เหตุผลที่แจ้ง
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                  Icon(Icons.description, color: Colors.red.shade600, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'เหตุผลที่แจ้ง',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'อธิบายปัญหาที่พบ เช่น หน้าจอเป็นเส้น, เปิดไม่ติด',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // รูปภาพหลักฐาน
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
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
                    children: [
                      Icon(Icons.photo_camera, color: Colors.red.shade600, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'รูปภาพหลักฐาน',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '${reportImages.length} รูป',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
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
        ),
        const SizedBox(height: 30),

        // ปุ่มส่งแจ้งปัญหา
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade500, Colors.red.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _submitReport,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.send, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'ส่งแจ้งปัญหา',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // Helpers
  Widget _buildDropdownLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  BoxDecoration _buildDropdownDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildEmptyImageState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_camera, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('ยังไม่มีรูปภาพ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 20),
            label: const Text('เพิ่มรูปภาพ', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade500),
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
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200, width: 2),
        ),
        child: Icon(Icons.add_photo_alternate, color: Colors.red.shade400, size: 35),
      ),
    );
  }

  Widget _buildImageCard(int index) {
     return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: FileImage(File(reportImages[index])), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 5, right: 5,
          child: InkWell(
            onTap: () => _deleteImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
