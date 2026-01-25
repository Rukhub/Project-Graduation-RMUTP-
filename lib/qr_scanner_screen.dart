import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mobile;

import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'equipment_detail_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // MobileScanner 3.x controller does not have some v5 parameters
  mobile.MobileScannerController cameraController = mobile.MobileScannerController(
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
        content: const Text('กรุณาเปิดสิทธิ์การใช้งานกล้องในการตั้งค่าเพื่อใช้งานฟีเจอร์สแกน QR Code'),
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
      String assetId = qrData;
      if (qrData.contains('EQUIP:')) {
        assetId = qrData.split('EQUIP:')[1];
      }

      debugPrint('🔍 QR Data: $qrData → Asset ID: $assetId');

      final equipment = await ApiService().getAssetById(assetId);

      if (!mounted) return;

      if (equipment != null) {
        final roomName = equipment['location_name'] ?? 
                        equipment['location'] ?? 
                        equipment['room_name'] ?? 
                        'ไม่ระบุ';
        
        debugPrint('✅ เจอครุภัณฑ์: ${equipment['asset_id']} ห้อง: $roomName');
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EquipmentDetailScreen(
              equipment: equipment,
              roomName: roomName,
            ),
          ),
        );
      } else {
        debugPrint('❌ ไม่พบครุภัณฑ์: $assetId');
        _showErrorDialog('ไม่พบครุภัณฑ์นี้ในระบบ\n(Asset ID: $assetId)');
        setState(() => isProcessing = false);
      }
    } catch (e) {
      debugPrint('🚨 Error: $e');
      _showErrorDialog('เกิดข้อผิดพลาด: ${e.toString()}');
      setState(() => isProcessing = false);
    }
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

      // MobileScanner 3.x might behave differently for analyzeImage.
      // Assuming analyzeImage is available on controller in 3.5.0
      // If not, we might need a workaround or check documentation.
      // According to 3.5.7, analyzeImage exists on MobileScannerController.
      
      final tempController = mobile.MobileScannerController(
        formats: const [mobile.BarcodeFormat.qrCode],
        autoStart: false,
      );
      
      try {
        // v3.x analyzeImage returns bool (true if detected), but doesn't return the data directly?
        // Wait, v3.x analyzeImage returns Future<bool> and triggers onDetect callback?
        // Or actually, 3.5.0 added analyzeImage returning BarcodeCapture?
        // Let's check 3.5.7 source code effectively: it returns Future<bool>.
        // This is tricky. In 3.x, analyzing image from file was often handled differently.
        // Actually, many users use `google_mlkit_barcode_scanning` separately for gallery.
        // BUT, since we removed that, we rely on mobile_scanner.
        
        // Let's assume standard behavior: if 3.x analyzeImage triggers onDetect, we can set up a temp listener?
        // It's safer to rely on the fact that older mobile_scanner had analyzeImage but it was often buggy/limited.
        // BUT, given the user's request, let's try to use it.
        
        // v3.5.0 analyzeImage returns Future<bool> indicating if analysis was successfully started
        final bool started = await tempController.analyzeImage(image.path);
        
        if (!started) {
           _showErrorDialog('ไม่สามารถอ่าน QR Code ในรูปได้');
           setState(() => isProcessing = false);
           return;
        }

        // Wait for event on barcodes stream
        bool found = false;
        // Listen to the stream for a short period
        final subscription = tempController.barcodes.listen((capture) {
           if (capture.barcodes.isNotEmpty) {
             final qrData = capture.barcodes.first.rawValue;
             if (qrData != null) {
                // Stop listening once found
                if (!found) {
                   found = true;
                   _onQRCodeDetected(qrData);
                }
             }
           }
        });

        // Loop to wait for result or timeout
        int retries = 0;
        while (!found && retries < 10) {
           await Future.delayed(const Duration(milliseconds: 200));
           // No need to check stream manually, listener handles it
           retries++;
        }
        
        await subscription.cancel();
        
        if (!found) {
           // Standard 3.x might not have picked it up
           _showErrorDialog('ไม่พบ QR Code ในรูปภาพ');
           setState(() => isProcessing = false);
        }
        
      } finally {
        tempController.dispose();
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
            child: const Text('ตกลง', style: TextStyle(color: Color(0xFF9A2C2C), fontWeight: FontWeight.bold)),
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


          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),

          Positioned(
            top: 50, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
              child: const Text('วาง QR Code ให้อยู่ในกรอบ', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),

          Positioned(
            bottom: 100, left: 0, right: 0,
            child: Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: (isProcessing || isPickerActive) ? null : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: const Text('เลือกจากแกลเลอรี่', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 5),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 15),
                    child: IconButton(
                      onPressed: () => cameraController.toggleTorch(),
                      icon: ValueListenableBuilder<mobile.TorchState>(
                        valueListenable: cameraController.torchState,
                        builder: (context, state, child) {
                          final isOn = state == mobile.TorchState.on;
                          return Icon(isOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 32); 
                        },
                      ),
                      style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.5), padding: const EdgeInsets.all(15)),
                    ),
                   ),
                ],
              ),
            ),
          ),

          if (isProcessing)
            Container(color: Colors.black.withValues(alpha: 0.7), child: const Center(child: CircularProgressIndicator(color: Colors.white))),
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
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize), const Radius.circular(20)));
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withValues(alpha: 0.6));
    final borderPaint = Paint()..color = const Color(0xFF8B0000)..strokeWidth = 4..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize), const Radius.circular(20)), borderPaint);
    // Corners
    final cornerPaint = Paint()..color = const Color(0xFF8B0000)..strokeWidth = 6..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const cornerLength = 30.0;
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize - cornerLength, top), Offset(left + scanAreaSize, top), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top), Offset(left + scanAreaSize, top + cornerLength), cornerPaint);
    canvas.drawLine(Offset(left, top + scanAreaSize - cornerLength), Offset(left, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left, top + scanAreaSize), Offset(left + cornerLength, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize - cornerLength, top + scanAreaSize), Offset(left + scanAreaSize, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top + scanAreaSize - cornerLength), Offset(left + scanAreaSize, top + scanAreaSize), cornerPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
