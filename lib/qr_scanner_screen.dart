import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mobile;

import 'package:image_picker/image_picker.dart';
import 'services/firebase_service.dart';
import 'equipment_detail_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // MobileScanner 3.x controller does not have some v5 parameters
  mobile.MobileScannerController cameraController =
      mobile.MobileScannerController(
        autoStart: false, // Keep false to prevent emulator crashes
        torchEnabled: false,
        returnImage: false,
        formats: const [mobile.BarcodeFormat.qrCode],
      );

  bool isProcessing = false;
  bool isPickerActive = false;
  bool hasPermission = false;

  // Track camera state manually since 3.x controller value might differ
  bool isCameraStarted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      hasPermission = status.isGranted;
    });

    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDialog();
      }
    } else if (status.isGranted) {
      // Delayed start to prevent camera crashes on emulator
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          try {
            await cameraController.start();
            if (mounted) {
              setState(() {
                isCameraStarted = true;
              });
            }
          } catch (e) {
            debugPrint('⚠️ Camera start error: $e');
            if (mounted) {
              setState(() {
                isCameraStarted = false;
              });
            }
          }
        }
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('ต้องการสิทธิ์การเข้าถึงกล้อง'),
        content: const Text(
          'กรุณาเปิดสิทธิ์การใช้งานกล้องในการตั้งค่าเพื่อใช้งานฟีเจอร์สแกน QR Code',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('ไปที่การตั้งค่า'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onQRCodeDetected(String qrData) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    try {
      String assetId = qrData.trim();

      // รองรับหลาย format
      if (qrData.contains('EQUIP:')) {
        assetId = qrData.split('EQUIP:')[1].trim();
      } else if (qrData.contains('equip:')) {
        assetId = qrData.split('equip:')[1].trim();
      }

      debugPrint('🔍 QR Data: $qrData → Asset ID: $assetId');

      // ค้นหาแบบปกติ
      var equipment = await FirebaseService().getAssetById(assetId);

      // ถ้าไม่เจอ ลอง trim ส่วนหลังหรือค้นหาแบบอื่น
      if (equipment == null && assetId.contains('-')) {
        // ลองค้นหาด้วยส่วนแรกของ ID (กรณี ID ยาวมาก)
        final parts = assetId.split('-');
        if (parts.length > 2) {
          final shortId = '${parts[0]}-${parts[1]}';
          debugPrint('🔍 ลองค้นหาด้วย: $shortId');
          equipment = await FirebaseService().searchAssetByPartialId(assetId);
        }
      }

      if (!mounted) return;

      if (equipment != null) {
        final normalizedEquipment = <String, dynamic>{...equipment};
        normalizedEquipment['asset_id'] =
            normalizedEquipment['asset_id'] ?? assetId;
        normalizedEquipment['asset_name'] =
            normalizedEquipment['asset_name'] ??
            normalizedEquipment['name_asset'];
        normalizedEquipment['type'] =
            normalizedEquipment['type'] ?? normalizedEquipment['asset_type'];

        String roomName =
            normalizedEquipment['location_name']?.toString() ??
            normalizedEquipment['location']?.toString() ??
            normalizedEquipment['room_name']?.toString() ??
            '';

        if (roomName.trim().isEmpty || roomName == 'ไม่ระบุ') {
          final locationId = normalizedEquipment['location_id'];
          final location = await FirebaseService().getLocationById(locationId);
          if (location != null && location.roomName.trim().isNotEmpty) {
            roomName = location.roomName;
          }
        }

        if (roomName.trim().isEmpty) {
          roomName = 'ไม่ระบุ';
        }

        normalizedEquipment['room_name'] = roomName;

        debugPrint(
          '✅ เจอครุภัณฑ์: ${normalizedEquipment['asset_id']} ห้อง: $roomName',
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EquipmentDetailScreen(
              equipment: normalizedEquipment,
              roomName: roomName,
            ),
          ),
        );

        if (mounted) {
          setState(() => isProcessing = false);
        }
      } else {
        debugPrint('❌ ไม่พบครุภัณฑ์: $assetId');
        _showNotFoundDialog(assetId, qrData);
        setState(() => isProcessing = false);
      }
    } catch (e) {
      debugPrint('🚨 Error: $e');
      _showErrorDialog('เกิดข้อผิดพลาด: ${e.toString()}');
      setState(() => isProcessing = false);
    }
  }

  void _showNotFoundDialog(String assetId, String rawQrData) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.search_off, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('ไม่พบครุภัณฑ์'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ไม่พบครุภัณฑ์นี้ในระบบ'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asset ID:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    assetId,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กรุณาตรวจสอบว่าครุภัณฑ์นี้มีอยู่ในระบบ',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ตกลง',
              style: TextStyle(
                color: Color(0xFF9A2C2C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    if (isProcessing || isPickerActive) {
      return;
    }

    setState(() => isPickerActive = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        setState(() => isPickerActive = false);
        return;
      }

      setState(() {
        isPickerActive = false;
        isProcessing = true;
      });

      debugPrint('📷 เลือกรูป: ${image.path}');

      final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
      try {
        final inputImage = InputImage.fromFilePath(image.path);
        final barcodes = await scanner.processImage(inputImage);

        String? qrData;
        for (final b in barcodes) {
          final v = b.rawValue;
          if (v != null && v.trim().isNotEmpty) {
            qrData = v;
            break;
          }
        }

        if (qrData == null) {
          _showErrorDialog('ไม่พบ QR Code ในรูปภาพ');
          setState(() => isProcessing = false);
          return;
        }

        debugPrint('🖼️ สแกนจากรูป: $qrData');
        if (mounted) {
          setState(() => isProcessing = false);
        }
        await _onQRCodeDetected(qrData);
      } finally {
        await scanner.close();
      }
    } catch (e) {
      debugPrint('🚨 Error picking image: $e');
      if (mounted) {
        setState(() {
          isPickerActive = false;
          isProcessing = false;
        });
        if (!e.toString().contains('already_active')) {
          _showErrorDialog('เกิดข้อผิดพลาด: กรุณาลองใหม่อีกครั้ง\n$e');
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('แจ้งเตือน'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ตกลง',
              style: TextStyle(
                color: Color(0xFF9A2C2C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'สแกน QR Code',
          style: TextStyle(
            fontFamily: 'InknutAntiqua',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (hasPermission)
            mobile.MobileScanner(
              controller: cameraController,
              // In v3.5.0: onDetect(BarcodeCapture capture)
              onDetect: (capture) {
                final List<mobile.Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && !isProcessing) {
                  final qrData = barcodes.first.rawValue;
                  if (qrData != null) {
                    debugPrint('📱 สแกนด้วยกล้อง: $qrData');
                    _onQRCodeDetected(qrData);
                  }
                }
              },
              // errorBuilder might be slightly different or same
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          CustomPaint(painter: ScannerOverlayPainter(), child: Container()),

          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'วาง QR Code ให้อยู่ในกรอบ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: (isProcessing || isPickerActive)
                        ? null
                        : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: const Text(
                      'เลือกจากแกลเลอรี่',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 15),
                    child: IconButton(
                      onPressed: () => cameraController.toggleTorch(),
                      icon: ValueListenableBuilder<mobile.TorchState>(
                        valueListenable: cameraController.torchState,
                        builder: (context, state, child) {
                          final isOn = state == mobile.TorchState.on;
                          return Icon(
                            isOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 32,
                          );
                        },
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double scanAreaSize = size.width * 0.7;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
          const Radius.circular(20),
        ),
      );
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      holePath,
    );
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    final borderPaint = Paint()
      ..color = const Color(0xFF8B0000)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
        const Radius.circular(20),
      ),
      borderPaint,
    );
    // Corners
    final cornerPaint = Paint()
      ..color = const Color(0xFF8B0000)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cornerLength = 30.0;
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top),
      Offset(left + scanAreaSize, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize - cornerLength),
      Offset(left, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      Offset(left + scanAreaSize, top + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
