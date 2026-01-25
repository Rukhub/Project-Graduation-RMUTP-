import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'api_service.dart';
import 'package:gal/gal.dart'; // Import Gal package

import 'report_problem_screen.dart'; // Import Report Screen

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

  // ข้อมูลผู้แจ้ง (เก็บไว้ตัวเดียวพอ)
  String? reporterName;
  String? reportReason;
  List<String> reportImages = [];

  // Internal DB ID
  int? internalId;

  // Upload state
  bool isUploadingImage = false;

  @override
  void initState() {
    super.initState();

    // 1. โหลดรูปภาพ
    // 1. โหลดรูปภาพ (รองรับทั้ง List และ String แบบ Comma separated)
    if (widget.equipment['images'] != null) {
      if (widget.equipment['images'] is List) {
        imagePaths = List<String>.from(widget.equipment['images']);
      } else if (widget.equipment['images'] is String) {
        // สูตรโบ: แตก String ด้วย comma
        final imgStr = widget.equipment['images'] as String;
        if (imgStr.isNotEmpty) {
          imagePaths = imgStr.split(',');
        }
      }
    }
    // Fallback: รองรับ key 'image_url' ด้วย (เผื่อ backend ส่งมา key นี้)
    if (imagePaths.isEmpty && widget.equipment['image_url'] != null) {
      final imgUrl = widget.equipment['image_url'].toString();
      if (imgUrl.isNotEmpty) {
        imagePaths = imgUrl.split(',');
      }
    }

    // 2. โหลดสถานะ
    equipmentStatus = widget.equipment['status'] ?? 'ปกติ';
    originalStatus = equipmentStatus;

    // 3. Set Internal ID
    internalId = widget.equipment['id'];

    // 4. โหลดข้อมูลผู้ตรวจ
    inspectorName =
        widget.equipment['inspectorName'] ?? widget.equipment['checker_name'];
    if (widget.equipment['inspectorImages'] != null) {
      if (widget.equipment['inspectorImages'] is List) {
        inspectorImages = List<String>.from(
          widget.equipment['inspectorImages'],
        );
      }
    }

    // 5. โหลดข้อมูลผู้แจ้ง
    reporterName =
        widget.equipment['reporterName'] ?? widget.equipment['reporter_name'];

    reportReason =
        widget.equipment['reportReason'] ??
        widget.equipment['report_reason'] ??
        widget.equipment['issue_detail'];

    if (widget.equipment['reportImages'] != null) {
      if (widget.equipment['reportImages'] is List) {
        reportImages = List<String>.from(widget.equipment['reportImages']);
      }
    }

    // 6. โหลดข้อมูลเพิ่มเติมจาก API ถ้าจำเป็น

    // if (shouldShowReporter) {
    //   _loadReportData(); // Removed
    // }

    // 7. โหลดข้อมูลล่าสุดเพื่อให้ได้ ID ที่ถูกต้อง
    _loadLatestData();
  }

  // Reload latest asset data (to get updated inspector/status/report)
  Future<void> _loadLatestData() async {
    try {
      // We don't have getAssetById, so we fetch assets by location and filter
      // (Optimization: In real app, should have getAssetById API)
      int locationId =
          int.tryParse(widget.equipment['location_id'].toString()) ?? 0;
      if (locationId == 0) return;

      final assets = await ApiService().getAssetsByLocation(locationId);
      final myId =
          widget.equipment['asset_id']?.toString() ??
          widget.equipment['id']?.toString();

      final updatedAsset = assets.firstWhere(
        (a) =>
            (a['asset_id']?.toString() == myId) ||
            (a['id']?.toString() == myId),
        orElse: () => {},
      );

      if (updatedAsset.isNotEmpty && mounted) {
        debugPrint('� Updated Asset Data: $updatedAsset');
        setState(() {
          // Update Status
          equipmentStatus = updatedAsset['status'] ?? equipmentStatus;
          originalStatus = equipmentStatus;

          // Update Inspector
          inspectorName =
              updatedAsset['inspectorName'] ?? updatedAsset['checker_name'];

          // Update Reporter (ดึงจาก Asset โดยตรง แทนที่จะไปดึงจาก Reports API ที่พัง)
          reporterName =
              updatedAsset['reporterName'] ?? updatedAsset['reporter_name'];
          reportReason =
              updatedAsset['reportReason'] ??
              updatedAsset['report_reason'] ??
              updatedAsset['issue_detail'];

          // Update Report Images (ROBUST PARSING from Asset)
          reportImages = [];

          // 1. Try 'reportImages' key
          if (updatedAsset['reportImages'] != null) {
            final val = updatedAsset['reportImages'];
            if (val is List) {
              reportImages = List<String>.from(val);
            } else if (val is String && val.isNotEmpty) {
              reportImages = val.split(',');
            }
          }

          // 2. Try 'image_url' (if status is broken/repairing, image_url might be the report image)
          if (reportImages.isEmpty &&
              (equipmentStatus == 'ชำรุด' ||
                  equipmentStatus == 'อยู่ระหว่างซ่อม') &&
              updatedAsset['image_url'] != null) {
            final val = updatedAsset['image_url'];
            if (val is String && val.isNotEmpty) {
              reportImages = val.split(',');
            } else if (val is List) {
              reportImages = List<String>.from(val);
            }
          }

          debugPrint('🏁 Final Parsed Report Images: $reportImages');

          // === NEW: อัปเดตรูปภาพหลักของครุภัณฑ์ ===
          // Update Main Asset Images (imagePaths)
          List<String> newImagePaths = [];
          if (updatedAsset['images'] != null) {
            final val = updatedAsset['images'];
            if (val is List) {
              newImagePaths = List<String>.from(val);
            } else if (val is String && val.isNotEmpty) {
              newImagePaths = val.split(',');
            }
          }
          // Fallback to 'image_url' if 'images' is empty (for normal status)
          if (newImagePaths.isEmpty &&
              equipmentStatus == 'ปกติ' &&
              updatedAsset['image_url'] != null) {
            final val = updatedAsset['image_url'];
            if (val is String && val.isNotEmpty) {
              newImagePaths = val.split(',');
            }
          }
          // Update state only if we found images
          if (newImagePaths.isNotEmpty) {
            imagePaths = newImagePaths;
            debugPrint('📷 Updated Main Images: $imagePaths');
          }
          // === END NEW ===

          // Update internal ID just in case
          if (updatedAsset['id'] != null) {
            internalId = updatedAsset['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error refreshing asset data: $e');
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

  void _deleteImage(int index) async {
    // ลบออกจาก local state ก่อน
    final deletedUrl = imagePaths[index];
    setState(() {
      imagePaths.removeAt(index);
    });

    // อัปเดต Backend ให้ลบรูปออกด้วย
    try {
      final updateId =
          widget.equipment['asset_id']?.toString() ??
          widget.equipment['id']?.toString() ??
          '';

      final newImageUrl = imagePaths.isNotEmpty ? imagePaths.join(',') : '';

      final result = await ApiService().updateAsset(updateId, {
        'asset_id': widget.equipment['asset_id'] ?? widget.equipment['id'],
        'type': widget.equipment['type'] ?? widget.equipment['asset_type'],
        'brand_model': widget.equipment['brand_model'],
        'location_id': widget.equipment['location_id'],
        'status': equipmentStatus,
        'inspectorName': inspectorName,
        'image_url': newImageUrl,
        'images': imagePaths,
      });

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบรูปภาพสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // ถ้าลบไม่สำเร็จ ให้เพิ่มกลับ
          setState(() {
            imagePaths.insert(index, deletedUrl);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'ลบรูปภาพไม่สำเร็จ'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Delete image error: $e');
      // Restore on error
      if (mounted) {
        setState(() {
          imagePaths.insert(index, deletedUrl);
        });
      }
    }
  }

  Future<void> _uploadAndUpdateImage() async {
    if (imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกรูปภาพก่อน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isUploadingImage = true);

    try {
      // รวบรวม URLs สุดท้ายที่จะส่งไป Backend
      List<String> finalUrls = [];

      for (final path in imagePaths) {
        // เช็คว่าเป็น URL (http/https) หรือ ไฟล์ในเครื่อง
        if (path.startsWith('http://') || path.startsWith('https://')) {
          // เป็น URL อยู่แล้ว ไม่ต้องอัปโหลดใหม่
          finalUrls.add(path);
        } else {
          // เป็น local file path -> ต้องอัปโหลด
          final uploadedUrl = await ApiService().uploadImage(File(path));
          if (uploadedUrl != null) {
            finalUrls.add(uploadedUrl);
          } else {
            debugPrint('⚠️ Failed to upload: $path');
          }
        }
      }

      if (finalUrls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // อัปเดต local state ให้เป็น URLs แทน local paths
      setState(() {
        imagePaths = finalUrls;
      });

      // อัพเดต asset กับ Backend
      final updateId =
          widget.equipment['asset_id']?.toString() ??
          widget.equipment['id']?.toString() ??
          '';

      final updateData = {
        'asset_id': widget.equipment['asset_id'] ?? widget.equipment['id'],
        'type': widget.equipment['type'] ?? widget.equipment['asset_type'],
        'brand_model': widget.equipment['brand_model'],
        'location_id': widget.equipment['location_id'],
        'status': equipmentStatus,
        'inspectorName': inspectorName,
        'image_url': finalUrls.join(','), // สูตรโบ: รวมเป็น String เดียว
        'images': finalUrls,
      };

      final result = await ApiService().updateAsset(updateId, updateData);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัปโหลดรูปภาพสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'อัปเดตข้อมูลไม่สำเร็จ'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploadingImage = false);
      }
    }
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
                color: Color(0xFF9A2C2C),
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

  void _showStatusDialog() {
    String tempStatus = equipmentStatus;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.edit_note, color: Color(0xFF9A2C2C), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'เปลี่ยนสถานะ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusOption(
                    'ปกติ',
                    Colors.green,
                    tempStatus,
                    setDialogState,
                    (value) {
                      tempStatus = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildStatusOption(
                    'ชำรุด',
                    Colors.red,
                    tempStatus,
                    setDialogState,
                    (value) {
                      Navigator.pop(context); // Close dialog first
                      _navigateToReport();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildStatusOption(
                    'อยู่ระหว่างซ่อม',
                    Colors.orange,
                    tempStatus,
                    setDialogState,
                    (value) {
                      tempStatus = value;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey),
                  ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'บันทึก',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusOption(
    String status,
    Color color,
    String currentStatus,
    StateSetter setDialogState,
    Function(String) onSelect,
  ) {
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
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.grey.shade100,
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
    Color statusColor = originalStatus == 'ปกติ'
        ? Colors.green
        : originalStatus == 'ชำรุด'
        ? Colors.red
        : Colors.orange;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pop(context, {
          'status': equipmentStatus,
          'inspectorName': inspectorName,
          'image_url': imagePaths.isNotEmpty ? imagePaths.first : null,
          'images': imagePaths,
        });
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: const Color(0xFF9A2C2C),
          leading: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: Color(0xFF9A2C2C),
              ),
            ),
            onPressed: () {
              Navigator.pop(context, {
                'status': equipmentStatus,
                'inspectorName': inspectorName,
                'image_url': imagePaths.isNotEmpty ? imagePaths.first : null,
                'images': imagePaths,
              });
            },
          ),
          centerTitle: true,
          title: Column(
            children: [
              Text(
                widget.equipment['asset_id'] ??
                    widget.equipment['id'] ??
                    'ไม่ระบุรหัส',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                widget.roomName,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
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
              const SizedBox(height: 20),
            ],

            // QR Code Section (ย้ายมาไว้ท้ายสุด)
            _buildQRCodeSection(),
          ],
        ),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  Icon(
                    Icons.photo_library,
                    color: Colors.grey.shade700,
                    size: 24,
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
          // Upload Button
          if (images.isNotEmpty) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isUploadingImage ? null : _uploadAndUpdateImage,
                icon: isUploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload, color: Colors.white),
                label: Text(
                  isUploadingImage ? 'กำลังอัปโหลด...' : 'อัปโหลดรูปภาพ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9A2C2C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
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
            color: Colors.black.withValues(alpha: 0.05),
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
          _buildInfoRow(
            Icons.qr_code,
            'รหัสครุภัณฑ์',
            widget.equipment['asset_id'] ?? widget.equipment['id'] ?? '-',
            const Color(0xFF5593E4),
          ),
          const Divider(height: 30),
          _buildInfoRow(
            Icons.branding_watermark,
            'ยี่ห้อ/รุ่น',
            widget.equipment['brand_model'] ?? '-',
            const Color(0xFFFECC52),
          ),
          const Divider(height: 30),
          _buildInfoRow(
            Icons.category,
            'ประเภท',
            widget.equipment['type'] ?? '-',
            const Color(0xFF99CD60),
          ),
          const Divider(height: 30),
          _buildInfoRow(
            Icons.location_on,
            'ห้อง',
            widget.roomName,
            const Color(0xFF9A2C2C),
          ),
        ],
      ),
    );
  }

  // Section สถานะ
  Widget _buildStatusSection(Color statusColor) {
    bool isAdmin = ApiService().currentUser?['role'] == 'admin';

    return InkWell(
      onTap: isAdmin ? _showStatusDialog : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                originalStatus == 'ปกติ'
                    ? Icons.check_circle
                    : originalStatus == 'ชำรุด'
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    originalStatus,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5593E4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_search,
                      color: Color(0xFF5593E4),
                      size: 24,
                    ),
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
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Logic to handle if backend saved ID instead of Name
                      String displayName = inspectorName ?? '-';

                      // Check if it's numeric (ID)
                      if (int.tryParse(displayName) != null) {
                        final currentUserId = ApiService()
                            .currentUser?['user_id']
                            ?.toString();
                        if (displayName == currentUserId) {
                          displayName =
                              ApiService().currentUser?['fullname'] ??
                              ApiService().currentUser?['username'] ??
                              displayName;
                        } else {
                          displayName = 'ผู้ตรวจสอบ #$displayName';
                        }
                      } else if (displayName == '-') {
                        // Fallback to current user if null
                        displayName =
                            ApiService().currentUser?['fullname'] ??
                            ApiService().currentUser?['username'] ??
                            'Admin';
                      }

                      return Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // ... images ...
        ],
      ),
    );
  }

  Future<void> _navigateToReport() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportProblemScreen(
          equipment: widget.equipment,
          roomName: widget.roomName,
        ),
      ),
    );

    // Update UI immediately from result
    if (result != null && result is Map && mounted) {
      setState(() {
        if (result['status'] != null) {
          equipmentStatus = result['status'];
          originalStatus = equipmentStatus;
        }
        if (result['reporterName'] != null) {
          reporterName = result['reporterName'];
        }
        if (result['reportReason'] != null) {
          reportReason = result['reportReason'];
        }
        if (result['issue_detail'] != null) {
          reportReason = result['issue_detail']; // Support both keys
        }
      });
    }

    // Refresh data from API to be sure
    await Future.delayed(const Duration(seconds: 1));
    await _loadLatestData();
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
            color: Colors.red.withValues(alpha: 0.08),
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
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.report_problem,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'การแจ้งปัญหา',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Text(
                    'รายงานข้อขัดข้อง',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ชื่อผู้แจ้ง
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0), // Soft red background
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 18,
                  child: Icon(
                    Icons.person,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ผู้แจ้ง',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade300,
                      ),
                    ),
                    Text(
                      reporterName ?? 'ยังไม่มีผู้แจ้ง',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                        fontStyle: reporterName != null
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // เหตุผล (Report Reason)
          // Always show this section if there's a problem, show placeholder if empty but status is broken
          if (reportReason != null || equipmentStatus == 'ชำรุด') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notes, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'รายละเอียด / สาเหตุ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (reportReason != null && reportReason!.isNotEmpty)
                        ? reportReason!
                        : 'ไม่ได้ระบุรายละเอียด',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Evidence Images (รูปภาพหลักฐาน)
          if (reportImages.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              'หลักฐานภาพถ่าย',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100, // เพิ่มความสูงหน่อย
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: reportImages.length,
                itemBuilder: (context, index) {
                  final imgPath = reportImages[index];
                  final isNetwork = imgPath.startsWith('http');

                  return GestureDetector(
                    onTap: () {
                      // Show Full Image Dialog
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  color: Colors.transparent,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: isNetwork
                                    ? Image.network(
                                        imgPath,
                                        fit: BoxFit.contain,
                                      )
                                    : Image.file(
                                        File(imgPath),
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 100, // เพิ่มขนาดหน่อย
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                        color: Colors.grey.shade100,
                        image: DecorationImage(
                          image: isNetwork
                              ? NetworkImage(imgPath)
                              : FileImage(File(imgPath)) as ImageProvider,
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {
                            debugPrint('🖼️ Image Load Error: $exception');
                          },
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
            color: const Color(0xFF99CD60).withValues(alpha: 0.4),
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 24,
            ),
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
                    color: Colors.white.withValues(alpha: 0.9),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAddImage,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
            label: const Text(
              'เพิ่มรูปภาพ',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9A2C2C),
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

  Widget _buildAddImageButton(VoidCallback onAddImage) {
    return InkWell(
      onTap: onAddImage,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF9A2C2C).withValues(alpha: 0.3),
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

  Widget _buildImageCard(
    List<String> images,
    int index,
    Function(int) onDelete,
  ) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showFullScreenImage(context, images[index]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: images[index].startsWith('http')
                    ? NetworkImage(images[index])
                    : FileImage(File(images[index])) as ImageProvider,
                fit: BoxFit.cover,
              ),
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Black background with dismiss tap
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
              ),
            ),
            // Zoomable Image
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: imageUrl.startsWith('http')
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : Image.file(File(imageUrl), fit: BoxFit.contain),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
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
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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

  // QR Code Section
  Widget _buildQRCodeSection() {
    final assetId =
        widget.equipment['asset_id'] ?? widget.equipment['id'] ?? 'UNKNOWN';
    final qrData = 'EQUIP:$assetId'; // รูปแบบ QR: EQUIP:KUYKRIS

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_2, color: Colors.grey.shade700, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'QR Code ครุภัณฑ์',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _saveQRCodeToGallery(qrData, assetId),
                    icon: const Icon(Icons.save_alt, color: Color(0xFF9A2C2C)),
                    tooltip: 'บันทึกลงเครื่อง',
                  ),
                  IconButton(
                    onPressed: () => _shareQRCode(qrData, assetId),
                    icon: const Icon(Icons.share, color: Color(0xFF9A2C2C)),
                    tooltip: 'แชร์ QR Code',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF9A2C2C), width: 3),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF9A2C2C),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF9A2C2C),
              ),
            ),
          ),

          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF9A2C2C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF9A2C2C),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'สแกนเพื่อดูรายละเอียดครุภัณฑ์',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
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

  // ฟังก์ชันแชร์ QR Code
  Future<void> _shareQRCode(String qrData, String assetId) async {
    try {
      // สร้าง QR Code เป็นรูปภาพ
      final qrValidationResult = QrValidator.validate(
        data: qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          gapless: true,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF9A2C2C),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF9A2C2C),
          ),
        );

        // แสดง loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กำลังสร้าง QR Code...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        // แปลงเป็น image
        final picData = await painter.toImageData(
          512,
          format: ui.ImageByteFormat.png,
        );

        if (picData != null) {
          try {
            // บันทึกชั่วคราว - ตรวจสอบว่า path_provider พร้อมหรือยัง
            final directory = await getTemporaryDirectory();
            final path = '${directory.path}/QR_$assetId.png';
            final file = File(path);
            await file.writeAsBytes(picData.buffer.asUint8List());

            // แชร์ไฟล์
            await Share.shareXFiles([
              XFile(path),
            ], text: 'QR Code ครุภัณฑ์: $assetId\nสแกนเพื่อดูรายละเอียด');
          } on PlatformException catch (e) {
            // จัดการกรณี path_provider ยังไม่พร้อม หรือไม่ได้ Restart
            debugPrint('⚠️ Platform error: ${e.message}');

            String errorMessage = 'กรุณารอสักครู่แล้วลองใหม่อีกครั้ง';
            // ตรวจสอบว่าเป็น error เรื่อง channel connection หรือไม่
            if (e.code == 'channel-error' ||
                e.message?.contains('Unable to establish connection') == true) {
              errorMessage =
                  'กรุณาปิดและเปิดแอพใหม่ (Stop & Run) เพื่อใช้งานฟีเจอร์นี้';
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('🚨 Share QR error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ฟังก์ชันบันทึก QR Code ลง Gallery
  Future<void> _saveQRCodeToGallery(String qrData, String assetId) async {
    try {
      // 1. สร้าง QR Code Image
      final qrValidationResult = QrValidator.validate(
        data: qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          gapless: true,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF9A2C2C),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF9A2C2C),
          ),
          embeddedImageStyle: null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กำลังบันทึกรูปภาพ...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        // 2. แปลงเป็นไฟล์ชั่วคราว
        final picData = await painter.toImageData(
          512,
          format: ui.ImageByteFormat.png,
        );

        if (picData != null) {
          final directory = await getTemporaryDirectory();
          final path = '${directory.path}/QR_$assetId.png';
          final file = File(path);
          await file.writeAsBytes(picData.buffer.asUint8List());

          // 3. บันทึกลง Gallery ด้วย Gal
          await Gal.putImage(path);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('บันทึกลง Gallery เรียบร้อยแล้ว ✅'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } on GalException catch (e) {
      debugPrint('🚨 Gal Error: $e');
      String errorMsg = 'เกิดข้อผิดพลาดในการบันทึก';
      if (e.type == GalExceptionType.accessDenied) {
        errorMsg = 'ไม่ได้รับอนุญาตให้เข้าถึงรูปภาพ กรุณาเปิดสิทธิ์ในตั้งค่า';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('🚨 Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
