import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> equipment;
  final String roomName;

  const EquipmentDetailScreen({
    super.key,
    required this.equipment,
    required this.roomName,
  });

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  List<String> imagePaths = [];
  String equipmentStatus = 'ปกติ';
  late String originalStatus;

  // ข้อมูลผู้ตรวจ
  String? inspectorName;
  List<String> inspectorImages = [];

  // ข้อมูลผู้แจ้ง
  String? reporterName;
  String? reportReason;
  List<String> reportImages = [];

  @override
  void initState() {
    super.initState();
    // โหลดข้อมูลจาก equipment
    if (widget.equipment['images'] != null) {
      imagePaths = List<String>.from(widget.equipment['images']);
    }
    if (widget.equipment['status'] != null) {
      equipmentStatus = widget.equipment['status'];
    }
    originalStatus = equipmentStatus;

    // โหลดข้อมูลผู้ตรวจ
    inspectorName = widget.equipment['inspectorName'];
    if (widget.equipment['inspectorImages'] != null) {
      inspectorImages = List<String>.from(widget.equipment['inspectorImages']);
    }

    // โหลดข้อมูลผู้แจ้ง
    reporterName = widget.equipment['reporterName'];
    reportReason = widget.equipment['reportReason'];
    if (widget.equipment['reportImages'] != null) {
      reportImages = List<String>.from(widget.equipment['reportImages']);
    }
  }

  bool get hasStatusChanged => equipmentStatus != originalStatus;

  // ตรวจสอบว่าควรแสดงข้อมูลผู้ตรวจหรือไม่
  bool get shouldShowInspector => 
      equipmentStatus == 'ปกติ' || equipmentStatus == 'อยู่ระหว่างซ่อม';

  // ตรวจสอบว่าควรแสดงข้อมูลผู้แจ้งหรือไม่
  bool get shouldShowReporter => 
      equipmentStatus == 'ชำรุด' || equipmentStatus == 'อยู่ระหว่างซ่อม';

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        imagePaths.add(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        imagePaths.add(photo.path);
      });
    }
  }

  void _deleteImage(int index) {
    setState(() {
      imagePaths.removeAt(index);
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
              Text('เพิ่มรูปภาพ', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showStatusDialog() {
    String tempStatus = equipmentStatus;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.edit_note, color: Color(0xFF9A2C2C), size: 28),
                  SizedBox(width: 10),
                  Text('เปลี่ยนสถานะ', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusOption('ปกติ', Colors.green, tempStatus, setDialogState, (value) {
                    tempStatus = value;
                  }),
                  const SizedBox(height: 10),
                  _buildStatusOption('ชำรุด', Colors.red, tempStatus, setDialogState, (value) {
                    tempStatus = value;
                  }),
                  const SizedBox(height: 10),
                  _buildStatusOption('อยู่ระหว่างซ่อม', Colors.orange, tempStatus, setDialogState, (value) {
                    tempStatus = value;
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      equipmentStatus = tempStatus;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusOption(String status, Color color, String currentStatus, 
      StateSetter setDialogState, Function(String) onSelect) {
    bool isSelected = currentStatus == status;
    return InkWell(
      onTap: () {
        setDialogState(() {
          onSelect(status);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 15),
            Text(
              status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = equipmentStatus == 'ปกติ'
        ? Colors.green
        : equipmentStatus == 'ชำรุด'
            ? Colors.red
            : Colors.orange;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF9A2C2C)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.equipment['id'] ?? 'ไม่ระบุรหัส',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.roomName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // รูปภาพครุภัณฑ์ปกติ
          _buildImageSection(
            title: 'รูปภาพครุภัณฑ์',
            images: imagePaths,
            color: const Color(0xFF5593E4),
            onAddImage: _showImageSourceDialog,
            onDeleteImage: _deleteImage,
          ),
          const SizedBox(height: 20),

          // ข้อมูลพื้นฐาน
          _buildBasicInfoSection(),
          const SizedBox(height: 20),

          // สถานะ
          _buildStatusSection(statusColor),
          const SizedBox(height: 20),

          // ข้อมูลผู้ตรวจ (แสดงเมื่อ ปกติ หรือ อยู่ระหว่างซ่อม)
          if (shouldShowInspector) ...[
            _buildInspectorSection(),
            const SizedBox(height: 20),
          ],

          // ข้อมูลผู้แจ้ง (แสดงเมื่อ ชำรุด หรือ อยู่ระหว่างซ่อม)
          if (shouldShowReporter) ...[
            _buildReporterSection(),
            const SizedBox(height: 20),
          ],

          // ปุ่มยืนยัน (แสดงเมื่อสถานะเปลี่ยน)
          if (hasStatusChanged) ...[
            _buildConfirmButton(),
          ],
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Section รูปภาพ
  Widget _buildImageSection({
    required String title,
    required List<String> images,
    required Color color,
    required VoidCallback onAddImage,
    required Function(int) onDeleteImage,
  }) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.photo_library, color: Colors.grey.shade700, size: 24),
                  const SizedBox(width: 10),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${images.length} รูป',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          images.isEmpty
              ? _buildEmptyImageState(onAddImage)
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: images.length + 1,
                  itemBuilder: (context, index) {
                    if (index == images.length) {
                      return _buildAddImageButton(onAddImage);
                    }
                    return _buildImageCard(images, index, onDeleteImage);
                  },
                ),
        ],
      ),
    );
  }

  // ข้อมูลพื้นฐาน
  Widget _buildBasicInfoSection() {
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
              Icon(Icons.info_outline, color: Colors.grey.shade700, size: 24),
              const SizedBox(width: 10),
              Text(
                'ข้อมูลพื้นฐาน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.qr_code, 'รหัสครุภัณฑ์', widget.equipment['id'] ?? '-', const Color(0xFF5593E4)),
          const Divider(height: 30),
          _buildInfoRow(Icons.category, 'ประเภท', widget.equipment['type'] ?? '-', const Color(0xFF99CD60)),
          const Divider(height: 30),
          _buildInfoRow(Icons.location_on, 'ห้อง', widget.roomName, const Color(0xFF9A2C2C)),
        ],
      ),
    );
  }

  // Section สถานะ
  Widget _buildStatusSection(Color statusColor) {
    return InkWell(
      onTap: _showStatusDialog,
      child: Container(
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                equipmentStatus == 'ปกติ'
                    ? Icons.check_circle
                    : equipmentStatus == 'ชำรุด'
                        ? Icons.error
                        : Icons.build_circle,
                color: statusColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สถานะ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    equipmentStatus,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }

  // Section ผู้ตรวจ
  Widget _buildInspectorSection() {
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
                  color: const Color(0xFF5593E4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_search, color: Color(0xFF5593E4), size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'ผู้ตรวจสอบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // ชื่อผู้ตรวจ
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.grey.shade600, size: 22),
                const SizedBox(width: 12),
                Text(
                  inspectorName ?? 'ยังไม่มีผู้ตรวจสอบ',
                  style: TextStyle(
                    fontSize: 15,
                    color: inspectorName != null ? Colors.black87 : Colors.grey.shade500,
                    fontStyle: inspectorName != null ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // รูปภาพจากผู้ตรวจ
          if (inspectorImages.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              'รูปภาพจากผู้ตรวจ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: inspectorImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: FileImage(File(inspectorImages[index])),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Section ผู้แจ้ง
  Widget _buildReporterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.08),
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
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.report_problem, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'การแจ้งปัญหา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // ชื่อผู้แจ้ง
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.red, size: 22),
                const SizedBox(width: 12),
                Text(
                  reporterName ?? 'ยังไม่มีผู้แจ้ง',
                  style: TextStyle(
                    fontSize: 15,
                    color: reporterName != null ? Colors.black87 : Colors.grey.shade500,
                    fontStyle: reporterName != null ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // เหตุผล
          if (reportReason != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: Colors.grey.shade600, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'เหตุผลที่แจ้ง',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reportReason!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // รูปภาพหลักฐาน
          if (reportImages.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              'รูปภาพหลักฐาน',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: reportImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200, width: 2),
                      image: DecorationImage(
                        image: FileImage(File(reportImages[index])),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ปุ่มยืนยัน
  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF99CD60), Color(0xFF7AB34D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF99CD60).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'มีการเปลี่ยนแปลงสถานะ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$originalStatus → $equipmentStatus',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, {
                'status': equipmentStatus,
                'inspectorName': inspectorName,
                'inspectorImages': inspectorImages,
                'reporterName': reporterName,
                'reportReason': reportReason,
                'reportImages': reportImages,
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('บันทึกสถานะ "$equipmentStatus" สำเร็จ'),
                  backgroundColor: const Color(0xFF99CD60),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('ยืนยัน'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF99CD60),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyImageState(VoidCallback onAddImage) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_camera, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            'ยังไม่มีรูปภาพ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กดปุ่มด้านล่างเพื่อเพิ่มรูป',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAddImage,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
            label: const Text('เพิ่มรูปภาพ', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9A2C2C),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton(VoidCallback onAddImage) {
    return InkWell(
      onTap: onAddImage,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF9A2C2C).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF9A2C2C).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.add_photo_alternate,
          color: Color(0xFF9A2C2C),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildImageCard(List<String> images, int index, Function(int) onDelete) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(File(images[index])),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: InkWell(
            onTap: () => onDelete(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}