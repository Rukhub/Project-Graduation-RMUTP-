import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';

import 'dart:ui' as ui;

import 'api_service.dart';

import 'services/firebase_service.dart';

// import 'models/asset_model.dart';

import 'package:gal/gal.dart'; // Import Gal package

import 'widgets/equipment_image_grid.dart';



import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:async'; // For StreamSubscription



class EquipmentDetailScreen extends StatefulWidget {

  final Map<String, dynamic> equipment;

  final String roomName;

  final bool autoOpenCheckDialog; // ⭐ เพิ่มตัวแปรนี้



  const EquipmentDetailScreen({

    super.key,

    required this.equipment,

    required this.roomName,

    this.autoOpenCheckDialog = false, // Default เป็น false

  });



  @override

  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();

}



class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {

  final ImagePicker _picker = ImagePicker();

  

  // Realtime Update Subscription

  StreamSubscription<DocumentSnapshot>? _assetStreamSub;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _latestReportStreamSub;



  // State Variables

  List<String> imagePaths = [];

  bool isUploadingImage = false;

  String equipmentStatus = 'ปกติ';

  String originalStatus = 'ปกติ';

  int? internalId;

  String? inspectorName; // ชื่อผู้ตรวจสอบล่าสุด

  String? creatorName; // ชื่อผู้เพิ่มครุภัณฑ์

  String? reporterName;

  String? reportReason;

  String? latestReportDocId;

  DateTime? latestReportAt;

  DateTime? latestFinishedAt;

  String? latestFinishedRemark;

  String? latestFinishedImageUrl;

  String? latestFinishedByName;

  String? latestWorkerName;

  bool latestIsRepairAgain = false;

  String? latestPreviousReportId;

  String? assetName;

  String? brandModel;

  String? price;

  String? purchaseAt;

  String? createdAt;

  String? repairerId; // ⭐ New state for locking

  List<String> reportImages = [];

  String currentRoomName = ''; // ⭐ State variable for Room Name

  

  // ⭐ For Failed Status Details

  String? failedReason;

  String? failedImage;

  String? failedByName;

  

  // ⭐ For Last Audit Details (Success/Display)

  int? lastAuditStatus;

  String? lastAuditNote;



  // ⭐ For Latest Normal Audit (Inspector) - used when current status is Normal

  String? lastNormalInspectorName;

  String? lastNormalAuditNote;

  String? lastNormalEvidenceImage;



  // ⭐ For Latest Damaged Audit (status=0) - used when current status is Damaged

  String? lastDamagedInspectorName;

  String? lastDamagedAuditNote;

  String? lastDamagedEvidenceImage;

  DateTime? latestDamagedAuditAt;



  // ⭐ Admin check - ใช้ทั่วทั้ง widget

  bool get isAdmin => ApiService().currentUser?['role'] == 'admin';

  String get currentUid => ApiService().currentUser?['uid'] ?? '';



  // ประวัติการตรวจสอบ (ใช้สำหรับ Repairing Section)

  List<Map<String, dynamic>> checkLogs = [];



  @override

  void initState() {

    super.initState();

    void _setupRealtimeListener() {

      _subscribeToAssetChanges();

      _subscribeToLatestReportChanges();



      // ถ้าต้องการให้เปิดหน้าตรวจสอบทันที (สำหรับ Admin กดมาจาก History)

      if (widget.autoOpenCheckDialog) {

        WidgetsBinding.instance.addPostFrameCallback((_) {

          _showStatusDialog();

        });

      }

    }



    // Start realtime listener

    _setupRealtimeListener();



    // 1. โหลดรูปภาพ

    if (widget.equipment['images'] != null) {

      if (widget.equipment['images'] is List) {

        imagePaths = List<String>.from(widget.equipment['images']);

      } else if (widget.equipment['images'] is String) {

        final imgStr = widget.equipment['images'] as String;

        if (imgStr.isNotEmpty) {

          imagePaths = imgStr.split(',');

        }

      }

    }

    if (imagePaths.isEmpty && widget.equipment['asset_image_url'] != null) {

      final imgUrl = widget.equipment['asset_image_url'].toString();

      if (imgUrl.isNotEmpty) {

        imagePaths = imgUrl.split(',');

      }

    }



    // 2. โหลดสถานะ (assets.status ใหม่)

    // 1=ปกติ, 2=ชำรุด, 3=รอดำเนินการ, 4=ซ่อมไม่ได้

    final rawStatus = widget.equipment['asset_status'];

    final rawRepairerId = widget.equipment['repairer_id'];

    if (rawStatus == 1 || rawStatus == '1' || rawStatus == 'ปกติ') {

      equipmentStatus = 'ปกติ';

    } else if (rawStatus == 2 || rawStatus == '2' || rawStatus == 'ชำรุด') {

      equipmentStatus = 'ชำรุด';

    } else if (rawStatus == 3 || rawStatus == '3' || rawStatus == 'รอดำเนินการ') {

      // ถ้ามีคนรับงานแล้ว (มี repairer_id) ให้แสดงเป็นอยู่ระหว่างซ่อม

      if (rawRepairerId != null && rawRepairerId.toString().isNotEmpty) {

        equipmentStatus = 'อยู่ระหว่างซ่อม';

      } else {

        equipmentStatus = 'รอดำเนินการ';

      }

    } else if (rawStatus == 4 || rawStatus == '4' || rawStatus == 'ซ่อมไม่ได้') {

      equipmentStatus = 'ซ่อมไม่ได้';

    } else {

      equipmentStatus = 'ปกติ';

    }

    originalStatus = equipmentStatus;



    // 2.2 โหลดชื่อและราคา

    assetName = widget.equipment['asset_name']?.toString() ?? widget.equipment['name_asset']?.toString();

    brandModel = widget.equipment['brand_model']?.toString();

    price = widget.equipment['price']?.toString();



    // 3. Set Internal ID (Handle String/Int parsing safe)

    final rawId = widget.equipment['id'];

    if (rawId is int) {

      internalId = rawId;

    } else if (rawId is String) {

      internalId = int.tryParse(rawId);

    }



    // 4. โหลดข้อมูลผู้ตรวจ (ไว้แสดงคนล่าสุด)

    inspectorName =

        widget.equipment['inspectorName'] ?? widget.equipment['auditor_name'];



    // 5. โหลดข้อมูลผู้แจ้ง

    reporterName =

        widget.equipment['reporterName'] ?? widget.equipment['reporter_name'];



    reportReason =

        widget.equipment['reportReason'] ??

        widget.equipment['report_reason'] ??

        widget.equipment['issue_detail'];



    // Load Brand Model

    brandModel =

        widget.equipment['brand_model'] ?? widget.equipment['brand'] ?? '-';



    // Init currentRoomName

    currentRoomName = widget.roomName;



    if (widget.equipment['reportImages'] != null) {

      if (widget.equipment['reportImages'] is List) {

        reportImages = List<String>.from(widget.equipment['reportImages']);

      }

    }



    // 6. โหลดข้อมูลล่าสุด

    _loadLatestData();



    // 7. โหลดประวัติการตรวจสอบ

    _loadCheckLogs();



    // รีเฟรชข้อมูลตัวเราเองจาก Firestore (เพื่อให้ชื่อล่าสุดแสดงผลถูกต้อง)

    ApiService().refreshCurrentUser().then((_) {

      if (mounted) setState(() {});

    });

  }



  // โหลดประวัติการตรวจสอบ

  Future<void> _loadCheckLogs() async {

    final assetId =

        widget.equipment['asset_id']?.toString() ??

        widget.equipment['id']?.toString();



    if (assetId == null) return;



    try {

      final logs = await FirebaseService().getCheckLogs(assetId);

      if (mounted) {

        setState(() {

          checkLogs = logs;



          // อัปเดตชื่อผู้ตรวจสอบล่าสุดจาก audit logs (ถ้ามี)

          if (logs.isNotEmpty) {

            final latestLog = logs.first; // ล่าสุดอยู่อันดับแรก



            int? derivedStatus;

            final dynamic rawStatus = latestLog['audit_status'];

            if (rawStatus is int) {

              derivedStatus = rawStatus;

            } else {

              final s = rawStatus?.toString();

              if (s == '1' || s == 'ปกติ') derivedStatus = 1;

              if (s == '2' || s == 'ชำรุด') derivedStatus = 2;

              if (s == '3' || s == 'อยู่ระหว่างซ่อม') derivedStatus = 3;

              if (s == '4' || s == 'ซ่อมไม่ได้') derivedStatus = 4;

            }



            lastAuditStatus = derivedStatus;

            lastAuditNote = (latestLog['note'] ?? latestLog['remark'])?.toString();



            final fetchedInspectorName = latestLog['auditor_name']?.toString();

            if (fetchedInspectorName != null && fetchedInspectorName.isNotEmpty) {

              inspectorName = fetchedInspectorName;

            }



            // Keep the most recent "failed" details even if latest status is not 4

            Map<String, dynamic>? latestFailedLog;

            for (final log in logs) {

              final dynamic rs = log['audit_status'];

              int? sInt;

              if (rs is int) {

                sInt = rs;

              } else {

                final s = rs?.toString();

                if (s == '4' || s == 'ซ่อมไม่ได้') sInt = 4;

              }

              if (sInt == 4) {

                latestFailedLog = log;

                break;

              }

            }



            if (latestFailedLog != null) {

              final nextFailedReason =

                  (latestFailedLog['note'] ?? latestFailedLog['remark'])?.toString();

              final nextFailedImage = latestFailedLog['evidence_image']?.toString() ??

                  latestFailedLog['asset_image_url']?.toString();

              final nextFailedByName = latestFailedLog['auditor_name']?.toString();



              // Do not override the failed details from reports_history.

              // Only fill from logs when state is still empty.

              if (failedReason == null || failedReason!.trim().isEmpty) {

                failedReason = nextFailedReason;

              }

              if (failedImage == null || failedImage!.trim().isEmpty) {

                failedImage = nextFailedImage;

              }

              if (failedByName == null || failedByName!.trim().isEmpty) {

                failedByName = nextFailedByName;

              }

            }



            // Find latest "normal" audit for displaying the blue inspector block

            Map<String, dynamic>? latestNormalLog;

            for (final log in logs) {

              final dynamic rs = log['audit_status'];

              int? sInt;

              if (rs is int) {

                sInt = rs;

              } else {

                final s = rs?.toString();

                if (s == '1' || s == 'ปกติ') sInt = 1;

              }

              if (sInt == 1) {

                latestNormalLog = log;

                break;

              }

            }



            if (latestNormalLog != null) {

              lastNormalInspectorName =

                  latestNormalLog['auditor_name']?.toString();

              lastNormalAuditNote =

                  (latestNormalLog['note'] ?? latestNormalLog['remark'])?.toString();

              lastNormalEvidenceImage =

                  latestNormalLog['evidence_image']?.toString() ??

                      latestNormalLog['asset_image_url']?.toString();

            } else {

              lastNormalInspectorName = null;

              lastNormalAuditNote = null;

              lastNormalEvidenceImage = null;

            }



            // Find latest "damaged" audit for displaying latest evidence/note

            Map<String, dynamic>? latestDamagedLog;

            for (final log in logs) {

              final dynamic rs =

                  log['audit_status'];

              int? sInt;

              if (rs is int) {

                sInt = rs;

              } else {

                final s = rs?.toString();

                if (s == '2' || s == 'ชำรุด') sInt = 2;

              }

              if (sInt == 2) {

                latestDamagedLog = log;

                break;

              }

            }



            if (latestDamagedLog != null) {

              lastDamagedInspectorName =

                  latestDamagedLog['auditor_name']?.toString();

              lastDamagedAuditNote =

                  (latestDamagedLog['note'] ?? latestDamagedLog['remark'])?.toString();

              lastDamagedEvidenceImage = latestDamagedLog['evidence_image']?.toString() ??

                  latestDamagedLog['asset_image_url']?.toString();



              final t = latestDamagedLog['audited_at'];

              if (t is Timestamp) {

                latestDamagedAuditAt = t.toDate();

              } else if (t is DateTime) {

                latestDamagedAuditAt = t;

              }

            } else {

              lastDamagedInspectorName = null;

              lastDamagedAuditNote = null;

              lastDamagedEvidenceImage = null;

              latestDamagedAuditAt = null;

            }

          }

        });

      }

    } catch (e) {

      debugPrint(' Error loading check logs: $e');

    }

  }



  void _showRepairAgainDialog() async {

    await ApiService().refreshCurrentUser();



    final TextEditingController reasonController = TextEditingController();

    File? pickedImage;



    if (!mounted) return;



    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          title: const Text('ซ่อมอีกครั้ง'),

          content: StatefulBuilder(

            builder: (context, setDialogState) {

              final screenW = MediaQuery.of(context).size.width;

              final dialogW = screenW.isFinite

                  ? (screenW * 0.90).clamp(280.0, 420.0)

                  : 420.0;



              return SizedBox(

                width: dialogW,

                child: SingleChildScrollView(

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text('กรุณาระบุเหตุผลที่ต้องกลับมาอยู่ระหว่างซ่อม:'),

                      const SizedBox(height: 12),

                      TextField(

                        controller: reasonController,

                        maxLines: 3,

                        decoration: InputDecoration(

                          hintText:

                              'เช่น พบวิธีซ่อมใหม่/เปลี่ยนอะไหล่/ส่งซ่อมภายนอก...',

                          border: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(12),

                          ),

                        ),

                      ),

                      const SizedBox(height: 12),

                      SizedBox(

                        width: double.infinity,

                        child: OutlinedButton.icon(

                          onPressed: () async {

                            try {

                              final source = await showModalBottomSheet<ImageSource>(

                                context: context,

                                showDragHandle: true,

                                shape: const RoundedRectangleBorder(

                                  borderRadius: BorderRadius.vertical(

                                    top: Radius.circular(20),

                                  ),

                                ),

                                builder: (sheetContext) {

                                  return SafeArea(

                                    child: Column(

                                      mainAxisSize: MainAxisSize.min,

                                      children: [

                                        ListTile(

                                          leading: const Icon(Icons.photo_camera_outlined),

                                          title: const Text('ถ่ายรูป'),

                                          onTap: () => Navigator.pop(

                                            sheetContext,

                                            ImageSource.camera,

                                          ),

                                        ),

                                        ListTile(

                                          leading: const Icon(Icons.photo_library_outlined),

                                          title: const Text('เลือกรูปจากคลัง'),

                                          onTap: () => Navigator.pop(

                                            sheetContext,

                                            ImageSource.gallery,

                                          ),

                                        ),

                                      ],

                                    ),

                                  );

                                },

                              );

                              if (source == null) return;



                              final picker = ImagePicker();

                              final image = await picker.pickImage(

                                source: source,

                                imageQuality: 85,

                              );

                              if (image == null) return;

                              if (!context.mounted) return;

                              setDialogState(() {

                                pickedImage = File(image.path);

                              });

                            } catch (e) {

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(

                                SnackBar(content: Text('ไม่สามารถเลือกรูปได้: $e')),

                              );

                            }

                          },

                          icon: const Icon(Icons.image_outlined),

                          label: Text(

                            pickedImage == null ? 'แนบรูปภาพ' : 'เปลี่ยนรูปภาพ',

                          ),

                        ),

                      ),

                      if (pickedImage != null) ...[

                        const SizedBox(height: 10),

                        ClipRRect(

                          borderRadius: BorderRadius.circular(12),

                          child: Image.file(

                            pickedImage!,

                            height: 140,

                            width: double.infinity,

                            fit: BoxFit.cover,

                            errorBuilder: (context, error, stackTrace) {

                              return Container(

                                height: 140,

                                width: double.infinity,

                                alignment: Alignment.center,

                                color: Colors.grey.shade200,

                                child: const Text('ไม่สามารถแสดงรูปได้'),

                              );

                            },

                          ),

                        ),

                      ],

                    ],

                  ),

                ),

              );

            },

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(context),

              child: const Text('ยกเลิก'),

            ),

            ElevatedButton(

              onPressed: () async {

                final reason = reasonController.text.trim();

                if (reason.isEmpty) {

                  ScaffoldMessenger.of(context).showSnackBar(

                    const SnackBar(content: Text('กรุณากรอกเหตุผล')),

                  );

                  return;

                }



                final assetIdStr = widget.equipment['asset_id']?.toString() ??

                    widget.equipment['id'].toString();



                final currentUserUid = ApiService().currentUser?['uid'] ?? 'unknown_uid';

                final currentUserName =

                    ApiService().currentUser?['fullname'] ?? 'Unknown Admin';



                // Create NEW reports_history document for repair-again (keep old report as history)

                final prevId = latestReportDocId;

                if (prevId == null || prevId.trim().isEmpty) {

                  ScaffoldMessenger.of(context).showSnackBar(

                    const SnackBar(content: Text('ไม่พบรายการแจ้งซ่อมเดิมสำหรับอ้างอิง')),

                  );

                  return;

                }



                String? uploadedReportImageUrl;

                if (pickedImage != null) {

                  uploadedReportImageUrl =

                      await FirebaseService().uploadReportImage(pickedImage!, assetIdStr);

                }



                final newReportId = await FirebaseService().createRepairAgainReport(

                  assetId: assetIdStr,

                  previousReportId: prevId,

                  reason: reason,

                  workerId: currentUserUid,

                  workerName: currentUserName,

                  reportImageUrl: uploadedReportImageUrl,

                );



                // Update asset status + lock

                await FirebaseService().updateAsset(assetIdStr, {

                  'asset_status': 3,

                  'repairer_id': currentUid,

                  'auditor_name': currentUserName,

                  'condemned_at': FieldValue.delete(),

                  'audited_at': DateTime.now(),

                });



                if (!mounted) return;

                Navigator.pop(context);

                setState(() {

                  equipmentStatus = 'อยู่ระหว่างซ่อม';

                  originalStatus = equipmentStatus;

                  latestReportDocId = newReportId;

                });

                _loadLatestData();

              },

              child: const Text('ยืนยัน'),

            ),

          ],

        );

      },

    );

  }



  void _showReportProblemDialog() {

    final TextEditingController noteController = TextEditingController();

    File? evidenceImage;

    final String currentUserUid = ApiService().currentUser?['uid'] ?? '';

    final String currentUserName = ApiService().currentUser?['fullname'] ?? 'ไม่ระบุ';

    final String assetIdStr =

        widget.equipment['asset_id']?.toString() ?? widget.equipment['id'].toString();



    showDialog(

      context: context,

      builder: (context) {

        return StatefulBuilder(

          builder: (ctx, setDialogState) {

            return AlertDialog(

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(24),

              ),

              titlePadding: EdgeInsets.zero,

              title: ClipRRect(

                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

                child: Container(

                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(

                    gradient: LinearGradient(

                      colors: [Colors.red.shade400, Colors.red.shade700],

                      begin: Alignment.topLeft,

                      end: Alignment.bottomRight,

                    ),

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

                          Icons.report_problem_rounded,

                          color: Colors.white,

                          size: 28,

                        ),

                      ),

                      const SizedBox(width: 12),

                      const Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              'ชำรุด / แจ้งปัญหา',

                              style: TextStyle(

                                color: Colors.white,

                                fontSize: 20,

                                fontWeight: FontWeight.bold,

                              ),

                            ),

                            SizedBox(height: 2),

                            Text(

                              'รายงานข้อขัดข้องและแนบหลักฐาน',

                              style: TextStyle(

                                color: Colors.white70,

                                fontSize: 13,

                              ),

                            ),

                          ],

                        ),

                      ),

                    ],

                  ),

                ),

              ),

              content: SingleChildScrollView(

                child: Padding(

                  padding: const EdgeInsets.all(20),

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [

                      Container(

                        padding: const EdgeInsets.symmetric(

                          horizontal: 14,

                          vertical: 12,

                        ),

                        decoration: BoxDecoration(

                          color: Colors.grey.shade50,

                          borderRadius: BorderRadius.circular(14),

                          border: Border.all(color: Colors.grey.shade200),

                        ),

                        child: Row(

                          children: [

                            Container(

                              padding: const EdgeInsets.all(8),

                              decoration: BoxDecoration(

                                color: Colors.red.withValues(alpha: 0.08),

                                borderRadius: BorderRadius.circular(8),

                              ),

                              child: const Icon(

                                Icons.person_rounded,

                                size: 18,

                                color: Colors.red,

                              ),

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(

                                    'ผู้แจ้ง',

                                    style: TextStyle(

                                      color: Colors.grey.shade500,

                                      fontSize: 11,

                                      fontWeight: FontWeight.w600,

                                    ),

                                  ),

                                  Text(

                                    currentUserName,

                                    maxLines: 1,

                                    overflow: TextOverflow.ellipsis,

                                    style: const TextStyle(

                                      color: Colors.black87,

                                      fontSize: 14,

                                      fontWeight: FontWeight.bold,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                          ],

                        ),

                      ),

                      const SizedBox(height: 24),

                      Row(

                        children: [

                          Icon(

                            Icons.camera_alt,

                            color: Colors.red.shade700,

                            size: 20,

                          ),

                          const SizedBox(width: 8),

                          Text(

                            'หลักฐานภาพถ่าย',

                            style: TextStyle(

                              fontWeight: FontWeight.bold,

                              fontSize: 14,

                              color: Colors.red.shade700,

                            ),

                          ),

                          const Text(' *', style: TextStyle(color: Colors.red)),

                        ],

                      ),

                      const SizedBox(height: 8),

                      GestureDetector(

                        onTap: () async {

                          final source =

                              await showModalBottomSheet<ImageSource>(

                            context: context,

                            shape: const RoundedRectangleBorder(

                              borderRadius: BorderRadius.vertical(

                                top: Radius.circular(20),

                              ),

                            ),

                            builder: (context) => Container(

                              padding: const EdgeInsets.all(20),

                              child: Column(

                                mainAxisSize: MainAxisSize.min,

                                children: [

                                  const Text(

                                    'เลือกแหล่งที่มาของรูปภาพ',

                                    style: TextStyle(

                                      fontSize: 18,

                                      fontWeight: FontWeight.bold,

                                    ),

                                  ),

                                  const SizedBox(height: 20),

                                  ListTile(

                                    leading: const Icon(Icons.camera_alt),

                                    title: const Text('ถ่ายรูป'),

                                    onTap: () => Navigator.pop(

                                      context,

                                      ImageSource.camera,

                                    ),

                                  ),

                                  ListTile(

                                    leading: const Icon(Icons.photo_library),

                                    title: const Text('เลือกจากแกลเลอรี่'),

                                    onTap: () => Navigator.pop(

                                      context,

                                      ImageSource.gallery,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                          );



                          if (source != null) {

                            final picked = await ImagePicker()

                                .pickImage(source: source);

                            if (picked != null && ctx.mounted) {

                              setDialogState(

                                () => evidenceImage = File(picked.path),

                              );

                            }

                          }

                        },

                        child: Container(

                          height: 140,

                          decoration: BoxDecoration(

                            color: evidenceImage == null

                                ? Colors.grey.shade100

                                : Colors.transparent,

                            borderRadius: BorderRadius.circular(16),

                            border: Border.all(color: Colors.grey.shade300),

                          ),

                          child: evidenceImage == null

                              ? const Center(

                                  child: Icon(

                                    Icons.add_a_photo,

                                    size: 50,

                                    color: Colors.grey,

                                  ),

                                )

                              : Image.file(

                                  evidenceImage!,

                                  fit: BoxFit.contain,

                                ),

                        ),

                      ),

                      const SizedBox(height: 24),

                      const Divider(height: 1, thickness: 1),

                      const SizedBox(height: 24),

                      Row(

                        children: [

                          Icon(

                            Icons.notes_rounded,

                            color: Colors.red.shade700,

                            size: 20,

                          ),

                          const SizedBox(width: 8),

                          Text(

                            'รายละเอียด / สาเหตุ',

                            style: TextStyle(

                              fontWeight: FontWeight.bold,

                              fontSize: 14,

                              color: Colors.red.shade700,

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 10),

                      TextField(

                        controller: noteController,

                        maxLines: 2,

                        decoration: InputDecoration(

                          hintText: 'ระบุปัญหาที่พบ (ถ้ามี)...',

                          hintStyle: TextStyle(

                            color: Colors.grey.shade400,

                            fontSize: 13,

                          ),

                          filled: true,

                          fillColor: Colors.grey.shade50,

                          contentPadding: const EdgeInsets.all(16),

                          border: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(14),

                            borderSide: BorderSide(color: Colors.grey.shade300),

                          ),

                          enabledBorder: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(14),

                            borderSide: BorderSide(

                              color: Colors.red.shade200,

                            ),

                          ),

                          focusedBorder: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(14),

                            borderSide: BorderSide(

                              color: Colors.red.shade700,

                              width: 2,

                            ),

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              ),

              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

              actions: [

                TextButton(

                  onPressed: () => Navigator.pop(context),

                  child: Text(

                    'ยกเลิก',

                    style: TextStyle(

                      color: Colors.grey.shade600,

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                ),

                const SizedBox(width: 8),

                ConstrainedBox(

                  constraints: const BoxConstraints(minWidth: 160),

                  child: ElevatedButton(

                    onPressed: () async {

                      if (evidenceImage == null) {

                        ScaffoldMessenger.of(context).showSnackBar(

                          const SnackBar(content: Text('กรุณาแนบรูปหลักฐาน')),

                        );

                        return;

                      }



                      try {

                        if (currentUserUid.trim().isEmpty) {

                          ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้งาน')),

                          );

                          return;

                        }



                        final String? evidenceUrl = await FirebaseService()

                            .uploadReportImage(evidenceImage!, assetIdStr);

                        final trimmedEvidenceUrl = evidenceUrl?.trim() ?? '';



                        await FirebaseService().createReport({

                          'asset_id': assetIdStr,

                          'reporter_id': currentUserUid,

                          'reporter_name': currentUserName,

                          'report_remark': noteController.text.trim(),

                          if (trimmedEvidenceUrl.isNotEmpty)

                            'report_image_url': trimmedEvidenceUrl,

                          'reported_at': FieldValue.serverTimestamp(),

                          'report_status': 1,

                        }, shouldCreateAuditLog: false);



                        await FirebaseService().updateAsset(assetIdStr, {

                          'asset_status': 2,

                          'audited_at': DateTime.now(),

                        });



                        if (!mounted) return;

                        Navigator.pop(context);

                        setState(() {

                          equipmentStatus = 'ชำรุด';

                          originalStatus = equipmentStatus;

                        });

                        _loadLatestData();

                        _loadCheckLogs();



                        ScaffoldMessenger.of(context).showSnackBar(

                          const SnackBar(

                            content: Text('แจ้งปัญหาเรียบร้อย'),

                            backgroundColor: Colors.green,

                          ),

                        );

                      } catch (e) {

                        debugPrint('Report problem error: $e');

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(

                          SnackBar(

                            content: Text('แจ้งปัญหาไม่ได้: $e'),

                            backgroundColor: Colors.red,

                          ),

                        );

                      }

                    },

                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.red.shade600,

                      padding: const EdgeInsets.symmetric(

                        vertical: 14,

                        horizontal: 10,

                      ),

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(14),

                      ),

                      elevation: 0,

                    ),

                    child: const FittedBox(

                      fit: BoxFit.scaleDown,

                      child: Text(

                        'ยืนยันแจ้งปัญหา',

                        maxLines: 1,

                        style: TextStyle(

                          color: Colors.white,

                          fontWeight: FontWeight.bold,

                          fontSize: 15,

                        ),

                      ),

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



  // Reload latest asset data

  @override

  void dispose() {

    _assetStreamSub?.cancel(); // Cancel subscription

    _latestReportStreamSub?.cancel();

    super.dispose();

  }



  void _subscribeToLatestReportChanges() {

    final assetId = widget.equipment['asset_id']?.toString() ??

        widget.equipment['id']?.toString();



    if (assetId == null || assetId.trim().isEmpty) return;



    _latestReportStreamSub = FirebaseFirestore.instance

        .collection('reports_history')

        .where('asset_id', isEqualTo: assetId)

        .snapshots()

        .listen((snapshot) {

      if (!mounted) return;

      if (snapshot.docs.isEmpty) return;



      final docs = snapshot.docs.toList();

      // Sort client-side by docId (customDocId contains sortable timestamp)

      docs.sort((a, b) => b.id.compareTo(a.id));



      // Keep only latest 10 docs for UI processing

      final limited = docs.take(10).toList();



      // Prefer active (pending/repairing) report. If none, fallback to first.

      final reports = limited

          .map((d) {

            final m = d.data();

            m['id'] = d.id;

            return m;

          })

          .toList();



      // Always resolve the latest closed report (completed/cancelled) for showing

      // finished remark/image, regardless of which report is chosen as "latest" for other UI.

      final closed = reports.where((r) {

        final c = FirebaseService.reportStatusToCode(r['report_status']);

        return c == 3 || c == 4;

      }).toList();

      closed.sort((a, b) {

        final da = _toDateTime(a['finished_at']) ?? _toDateTime(a['reported_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);

        final db = _toDateTime(b['finished_at']) ?? _toDateTime(b['reported_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);

        return db.compareTo(da);

      });



      final Map<String, dynamic>? latestClosed = closed.isNotEmpty ? closed.first : null;

      debugPrint(

        '🧾 EquipmentDetail latestClosed: asset_id=$assetId hasClosed=${latestClosed != null} '

        'status=${latestClosed == null ? null : latestClosed['report_status']} '

        'finished_remark=${latestClosed == null ? null : (latestClosed['finished_remark'] ?? latestClosed['remark_finished'] ?? latestClosed['remark_completed'])} '

        'finished_image_url=${latestClosed == null ? null : (latestClosed['finished_image_url'] ?? latestClosed['finished_image_url'])}',

      );



      Map<String, dynamic> latest = reports.first;

      final active = reports.where((r) {

        final c = FirebaseService.reportStatusToCode(r['report_status']);

        return c == 1 || c == 2;

      }).toList();

      if (active.isNotEmpty) {

        final pending =

            active.where((r) => FirebaseService.reportStatusToCode(r['report_status']) == 1).toList();

        final repairing =

            active.where((r) => FirebaseService.reportStatusToCode(r['report_status']) == 2).toList();



        // IMPORTANT:

        // - If asset is currently repairing, UI must reflect the repairing ticket.

        // - Otherwise, a newly created ticket (pending) should take priority.

        final bool isAssetRepairingNow = equipmentStatus == 'อยู่ระหว่างซ่อม';

        List<Map<String, dynamic>> candidates = isAssetRepairingNow

            ? (repairing.isNotEmpty ? repairing : pending)

            : (pending.isNotEmpty ? pending : repairing);

        if (candidates.isEmpty) candidates = active;



        Map<String, dynamic>? best;

        for (final r in candidates) {

          final rr = (r['report_remark'] ?? r['remark_report'])?.toString() ?? '';

          final img = r['report_image_url']?.toString() ?? '';

          final rra = r['remark_repair_again']?.toString() ?? '';

          if (rr.trim().isNotEmpty || img.trim().isNotEmpty || rra.trim().isNotEmpty) {

            best = r;

            break;

          }

        }

        latest = best ?? candidates.first;

      }



      // Derive fields

      final String? fetchedReporterName = latest['reporter_name']?.toString();

      final String? linkedReportId = latest['report_id']?.toString();

      final bool isRepairAgain =

          linkedReportId != null && linkedReportId.trim().isNotEmpty;



      String? fetchedReportReason;

      if (isRepairAgain) {

        fetchedReportReason = (latest['report_remark'] ?? latest['remark_report'])?.toString();

      } else {

        fetchedReportReason =

            (latest['report_remark'] ??

                    latest['remark_report'] ??

                    latest['issue'] ??

                    latest['report_reason'])

                ?.toString();

      }



      List<String> fetchedReportImages = [];

      if (!isRepairAgain) {

        final repImg = latest['report_image_url'];

        if (repImg != null && repImg.toString().trim().isNotEmpty) {

          fetchedReportImages = repImg

              .toString()

              .split(',')

              .where((s) => s.trim().isNotEmpty)

              .toList();

        }

      }



      // report_id is used to link to the previous report when "repair again" is created.

      final String? prevId = linkedReportId;



      DateTime? reportAt;

      final rt = latest['reported_at'] ?? latest['timestamp'];

      if (rt is Timestamp) {

        reportAt = rt.toDate();

      } else if (rt is DateTime) {

        reportAt = rt;

      }



      final String? docId = latest['id']?.toString();

      final int reportStatusCode =

          FirebaseService.reportStatusToCode(latest['report_status']);



      final String? fetchedWorkerName =

          (latest['worker_name'] ?? latest['workerName'])?.toString();



      final String? closedFinishedRemark = latestClosed == null

          ? null

          : (latestClosed['finished_remark'] ?? latestClosed['remark_finished'] ?? latestClosed['remark_completed'])

              ?.toString();

      final String? closedFinishedImage = latestClosed == null

          ? null

          : (latestClosed['finished_image_url'] ?? latestClosed['finished_image'] ?? latestClosed['finished_imageUrl'])

              ?.toString();

      final String? closedFinishedByName = latestClosed == null

          ? null

          : (latestClosed['worker_name'] ?? latestClosed['workerName'])?.toString();

      final DateTime? closedFinishedAt = latestClosed == null

          ? null

          : (_toDateTime(latestClosed['finished_at']) ?? _toDateTime(latestClosed['reported_at']));



      debugPrint(

        '✅ EquipmentDetail resolved finished: at=$closedFinishedAt remark="$closedFinishedRemark" image="$closedFinishedImage"',

      );



      final String? fetchedFinishedRemark =

          (latest['finished_remark'] ?? latest['remark_finished'] ?? latest['remark_completed'])

              ?.toString();

      final String? fetchedFinishedImage =

          (latest['finished_image_url'] ?? latest['finished_image'] ?? latest['finished_imageUrl'])

              ?.toString();



      // When report is cancelled (ซ่อมไม่ได้), treat remark_finished/finished_image_url

      // as the canonical "close job" fields (same as completed), with fallback to legacy fields.

      final String? fetchedFailedReason =

          (latest['finished_remark'] ?? latest['remark_finished'] ?? latest['remark_broken'] ?? latest['failed_reason'])

              ?.toString();

      final String? fetchedFailedImage =

          (latest['finished_image_url'] ?? latest['broken_image_url'] ?? latest['failed_image_url'])

              ?.toString();

      final String? fetchedFailedByName =

          (latest['worker_name'] ?? latest['workerName'])?.toString();



      DateTime? finishedAt;

      final ft = latest['finished_at'];

      if (ft is Timestamp) {

        finishedAt = ft.toDate();

      } else if (ft is DateTime) {

        finishedAt = ft;

      }



      setState(() {

        if (docId != null && docId.trim().isNotEmpty) {

          latestReportDocId = docId;

        }

        if (reportAt != null) {

          latestReportAt = reportAt;

        }



        // Update report fields immediately (realtime)

        reporterName = (fetchedReporterName != null && fetchedReporterName.isNotEmpty)

            ? fetchedReporterName

            : reporterName;

        reportReason = fetchedReportReason ?? reportReason;

        reportImages = fetchedReportImages;



        latestIsRepairAgain = isRepairAgain;

        latestPreviousReportId = prevId;



        if (reportStatusCode == 2) {

          if (fetchedWorkerName != null && fetchedWorkerName.trim().isNotEmpty) {

            latestWorkerName = fetchedWorkerName.trim();

          }

        }



        if (finishedAt != null) {

          latestFinishedAt = finishedAt;

        }



        if (reportStatusCode == 3 || reportStatusCode == 4) {

          if (fetchedFinishedRemark != null && fetchedFinishedRemark.trim().isNotEmpty) {

            latestFinishedRemark = fetchedFinishedRemark;

          }

          if (fetchedFinishedImage != null && fetchedFinishedImage.trim().isNotEmpty) {

            latestFinishedImageUrl = fetchedFinishedImage;

          }

        }



        if (closedFinishedAt != null) {

          latestFinishedAt = closedFinishedAt;

        }

        if (closedFinishedRemark != null && closedFinishedRemark.trim().isNotEmpty) {

          latestFinishedRemark = closedFinishedRemark;

        }

        if (closedFinishedImage != null && closedFinishedImage.trim().isNotEmpty) {

          latestFinishedImageUrl = closedFinishedImage;

        }

        if (closedFinishedByName != null && closedFinishedByName.trim().isNotEmpty) {

          latestFinishedByName = closedFinishedByName;

        }



        if (reportStatusCode == 4) {

          if (fetchedFailedReason != null && fetchedFailedReason.trim().isNotEmpty) {

            failedReason = fetchedFailedReason;

          }

          if (fetchedFailedImage != null && fetchedFailedImage.trim().isNotEmpty) {

            failedImage = fetchedFailedImage;

          }

          if (fetchedFailedByName != null && fetchedFailedByName.trim().isNotEmpty) {

            failedByName = fetchedFailedByName;

          }

        }

      });

    }, onError: (e) {

      debugPrint('🚨 Latest report stream error: $e');

    });

  }



  // Realtime Asset Listener

  void _subscribeToAssetChanges() {

    final assetId =

        widget.equipment['asset_id']?.toString() ??

        widget.equipment['id']?.toString();



    if (assetId == null) return;



    _assetStreamSub = FirebaseFirestore.instance

        .collection('assets')

        .doc(assetId)

        .snapshots()

        .listen((snapshot) {

      if (snapshot.exists && mounted) {

        final data = snapshot.data() as Map<String, dynamic>;



        // Update Status safely (assets.status ใหม่)

        final rawStatus = data['asset_status'];

        final rawRepairerId = data['repairer_id'];

        String newStatus = 'ปกติ';

        if (rawStatus == 1 || rawStatus == '1' || rawStatus == 'ปกติ') {

          newStatus = 'ปกติ';

        } else if (rawStatus == 2 || rawStatus == '2' || rawStatus == 'ชำรุด') {

          newStatus = 'ชำรุด';

        } else if (rawStatus == 3 || rawStatus == '3' || rawStatus == 'รอดำเนินการ') {

          if (rawRepairerId != null && rawRepairerId.toString().isNotEmpty) {

            newStatus = 'อยู่ระหว่างซ่อม';

          } else {

            newStatus = 'รอดำเนินการ';

          }

        } else if (rawStatus == 4 || rawStatus == '4' || rawStatus == 'ซ่อมไม่ได้') {

          newStatus = 'ซ่อมไม่ได้';

        }



        setState(() {

          equipmentStatus = newStatus;

          originalStatus = newStatus;

          repairerId = data['repairer_id']; // Update lock ID



          // Repair-again UI should only be visible during active repairing state

          if (newStatus != 'อยู่ระหว่างซ่อม') {

            latestIsRepairAgain = false;

            latestPreviousReportId = null;

          }



          // Update other fields if they change

          final inspector = (data['auditor_name'])?.toString();

          if (inspector != null && inspector.trim().isNotEmpty) {

            inspectorName = inspector;

          }

          if (data['asset_name'] != null) assetName = data['asset_name'];

        });



        // Avoid race condition: if asset just entered repairing state, re-evaluate

        // latest report so UI shows repairing/repair-again ticket (cycle/repairer) immediately.

        if (newStatus == 'อยู่ระหว่างซ่อม') {

          _loadLatestData();

        }

      }

    }, onError: (e) {

      debugPrint(" Asset Stream Error: $e");

    });

  }



  String _formatFinishedAt(DateTime? dt) {

    if (dt == null) return '-';

    final day = dt.day.toString().padLeft(2, '0');

    final month = dt.month.toString().padLeft(2, '0');

    final year = (dt.year + 543).toString();

    final hour = dt.hour.toString().padLeft(2, '0');

    final minute = dt.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';

  }



  DateTime? _toDateTime(dynamic v) {

    if (v == null) return null;

    if (v is Timestamp) return v.toDate();

    if (v is DateTime) return v;

    return DateTime.tryParse(v.toString());

  }



  // Keeping _loadLatestData for initial fallback or complex fetches (reports)

  Future<void> _loadLatestData() async {

    try {

      final assetId =

          widget.equipment['asset_id']?.toString() ??

          widget.equipment['id']?.toString();



      if (assetId == null) return;



      final updatedAsset = await FirebaseService().getAssetById(assetId);



      if (updatedAsset == null) {

        debugPrint(' Could not load asset data from Firestore');

        return;

      }



      if (mounted) {

        // Fetch reports specifically

        final myReports = await FirebaseService().getReports(assetId);



        // Fetch reporter name if report exists (BEFORE setState)

        String? fetchedReporterName;

        String? fetchedReportReason;

        List<String>? fetchedReportImages;

        String? fetchedFailedReason;

        String? fetchedFailedImage;

        String? fetchedFailedByName;

        String? fetchedLatestReportStatus;



        bool hasReportDoc = false;

        if (myReports.isNotEmpty) {

          // Always resolve latest closed report for finished remark/image.

          final closed = myReports.where((r) {

            final c = FirebaseService.reportStatusToCode(r['report_status']);

            return c == 3 || c == 4;

          }).toList();

          closed.sort((a, b) {

            final da = _toDateTime(a['finished_at']) ?? _toDateTime(a['reported_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);

            final db = _toDateTime(b['finished_at']) ?? _toDateTime(b['reported_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);

            return db.compareTo(da);

          });

          final latestClosed = closed.isNotEmpty ? closed.first : null;



          final String? closedFinishedRemark = latestClosed == null

              ? null

              : (latestClosed['finished_remark'] ?? latestClosed['remark_finished'] ?? latestClosed['remark_completed'])

                  ?.toString();

          final String? closedFinishedImage = latestClosed == null

              ? null

              : (latestClosed['finished_image_url'] ?? latestClosed['finished_image'] ?? latestClosed['finished_imageUrl'])

                  ?.toString();

          final DateTime? closedFinishedAt = latestClosed == null

              ? null

              : (_toDateTime(latestClosed['finished_at']) ?? _toDateTime(latestClosed['reported_at']));

          final String? closedFinishedByName = latestClosed == null

              ? null

              : (latestClosed['worker_name'] ?? latestClosed['workerName'])?.toString();



          debugPrint(

            '🧾 EquipmentDetail loadLatestData closed: at=$closedFinishedAt '

            'remark="${closedFinishedRemark ?? ''}" image="${closedFinishedImage ?? ''}"',

          );



          // Prefer active (pending/repairing) report. If none, fallback to first.

          final active = myReports.where((r) {

            final s = r['report_status']?.toString();

            if (s == null || s.isEmpty) return true;

            return s == 'pending' || s == 'repairing';

          }).toList();



          Map<String, dynamic> latest = myReports.first;

          if (active.isNotEmpty) {

            final pending =

                active.where((r) => r['report_status']?.toString() == 'pending').toList();

            final repairing = active

                .where((r) => r['report_status']?.toString() == 'repairing')

                .toList();



            final bool isAssetRepairingNow = equipmentStatus == 'อยู่ระหว่างซ่อม';

            List<Map<String, dynamic>> candidates = isAssetRepairingNow

                ? (repairing.isNotEmpty ? repairing : pending)

                : (pending.isNotEmpty ? pending : repairing);

            if (candidates.isEmpty) candidates = active;



            Map<String, dynamic>? best;

            for (final r in candidates) {

              final rr = (r['report_remark'] ?? r['remark_report'])?.toString() ?? '';

              final img = r['report_image_url']?.toString() ?? '';

              final rra = r['remark_repair_again']?.toString() ?? '';

              if (rr.trim().isNotEmpty ||

                  img.trim().isNotEmpty ||

                  rra.trim().isNotEmpty) {

                best = r;

                break;

              }

            }

            latest = best ?? candidates.first;

          }



          hasReportDoc = true;



          // Keep doc id for precise updates (start repair / failed repair)

          final dynamic docId = latest['id'];

          if (docId != null && docId.toString().trim().isNotEmpty) {

            latestReportDocId = docId.toString();

          }



          final int latestReportStatusCode =

              FirebaseService.reportStatusToCode(latest['report_status']);

          fetchedLatestReportStatus = latestReportStatusCode.toString();



          final String? fetchedWorkerName =

              (latest['worker_name'] ?? latest['workerName'])?.toString();



          final String? fetchedFinishedRemark =

              (latest['finished_remark'] ?? latest['remark_finished'] ?? latest['remark_completed'])

                  ?.toString();

          final String? fetchedFinishedImage =

              (latest['finished_image_url'] ?? latest['finished_image'] ?? latest['finished_imageUrl'])

                  ?.toString();



          // Prioritize reporter_name from document

          fetchedReporterName = latest['reporter_name']?.toString();



          // Fallback if name is missing but ID exists

          if (fetchedReporterName == null || fetchedReporterName == 'ไม่ระบุ') {

            final rId = latest['reporter_id'];

            if (rId != null) {

              final reporterUser =

                  await FirebaseService().getUserProfileByUid(rId);

              fetchedReporterName = reporterUser?.fullname ?? 'ไม่ระบุ';

            }

          }



          final String? linkedReportId = latest['report_id']?.toString();

          latestIsRepairAgain =

              linkedReportId != null && linkedReportId.trim().isNotEmpty;



          if (latestIsRepairAgain) {

            fetchedReportReason = (latest['report_remark'] ?? latest['remark_report'])?.toString();

          } else {

            fetchedReportReason =

                (latest['report_remark'] ??

                        latest['remark_report'] ??

                        latest['issue'] ??

                        latest['report_reason'])

                    ?.toString();

          }



          final rt = latest['reported_at'] ?? latest['timestamp'];

          if (rt is Timestamp) {

            latestReportAt = rt.toDate();

          } else if (rt is DateTime) {

            latestReportAt = rt;

          }



          if (!latestIsRepairAgain) {

            final repImg = latest['report_image_url'];

            if (repImg != null && repImg.toString().isNotEmpty) {

              fetchedReportImages = repImg

                  .toString()

                  .split(',')

                  .where((s) => s.isNotEmpty)

                  .toList();

            }

          } else {

            fetchedReportImages = [];

          }



          // Failed/Cancelled details

          if (latestReportStatusCode == 4) {

            fetchedFailedReason =

                (latest['finished_remark'] ?? latest['remark_finished'] ?? latest['remark_broken'] ?? latest['failed_reason'])

                    ?.toString();

            fetchedFailedImage =

                (latest['finished_image_url'] ?? latest['broken_image_url'] ?? latest['failed_image_url'])

                    ?.toString();

            fetchedFailedByName =

                (latest['worker_name'] ?? latest['workerName'])?.toString();

          }



          final ft = latest['finished_at'];

          if (ft is Timestamp) {

            latestFinishedAt = ft.toDate();

          } else if (ft is DateTime) {

            latestFinishedAt = ft;

          }



          if (latestReportStatusCode == 3 || latestReportStatusCode == 4) {

            if (fetchedFinishedRemark != null && fetchedFinishedRemark.trim().isNotEmpty) {

              latestFinishedRemark = fetchedFinishedRemark;

            }

            if (fetchedFinishedImage != null && fetchedFinishedImage.trim().isNotEmpty) {

              latestFinishedImageUrl = fetchedFinishedImage;

            }

          }



          if (latestReportStatusCode == 2) {

            if (fetchedWorkerName != null && fetchedWorkerName.trim().isNotEmpty) {

              latestWorkerName = fetchedWorkerName.trim();

            }

          }



          if (closedFinishedAt != null) {

            latestFinishedAt = closedFinishedAt;

          }

          if (closedFinishedRemark != null && closedFinishedRemark.trim().isNotEmpty) {

            latestFinishedRemark = closedFinishedRemark;

          }

          if (closedFinishedImage != null && closedFinishedImage.trim().isNotEmpty) {

            latestFinishedImageUrl = closedFinishedImage;

          }

          if (closedFinishedByName != null && closedFinishedByName.trim().isNotEmpty) {

            latestFinishedByName = closedFinishedByName;

          }

        }



        setState(() {

          // Map status

          // Map status (Robust)

          final s = updatedAsset['asset_status'];

          final rawRepairerId = updatedAsset['repairer_id'];

          if (s == 1 || s == '1' || s == 'ปกติ') {

            equipmentStatus = 'ปกติ';

          } else if (s == 2 || s == '2' || s == 'ชำรุด') {

            equipmentStatus = 'ชำรุด';

          } else if (s == 3 || s == '3' || s == 'รอดำเนินการ') {

            if (rawRepairerId != null && rawRepairerId.toString().isNotEmpty) {

              equipmentStatus = 'อยู่ระหว่างซ่อม';

            } else {

              equipmentStatus = 'รอดำเนินการ';

            }

          } else if (s == 4 || s == '4' || s == 'ซ่อมไม่ได้') {

            equipmentStatus = 'ซ่อมไม่ได้';

          } else {

            equipmentStatus = 'ปกติ';

          }



          originalStatus = equipmentStatus;

          inspectorName = updatedAsset['auditor_name'];

          repairerId = updatedAsset['repairer_id']; // Restore repairer lock ID

          creatorName = updatedAsset['created_name'];

          brandModel = updatedAsset['brand_model'] ?? updatedAsset['brandModel'];

          assetName = updatedAsset['asset_name'] ?? updatedAsset['assetName'];

          price = updatedAsset['price']?.toString();



          final rawAssetImages = updatedAsset['asset_image_url'];

          if (rawAssetImages != null && rawAssetImages.toString().isNotEmpty) {

            imagePaths = rawAssetImages

                .toString()

                .split(',')

                .where((s) => s.isNotEmpty)

                .toList();

          }



          // Unified Logic for Reporter Data (Report vs Asset Fallback)

          String? finalReporter = fetchedReporterName;

          String? finalReason = fetchedReportReason;

          List<String> finalImages = fetchedReportImages ?? [];



          // 1. Fallback for Name

          // If fetched is null or 'ไม่ระบุ', try Asset

          if (finalReporter == null || finalReporter == 'ไม่ระบุ') {

            finalReporter = (updatedAsset['reporter_name'] ?? updatedAsset['reporterName'])?.toString();

          }



          // 2. Fallback for Reason/Images from Asset ONLY when there's no report doc

          if (!hasReportDoc) {

            if (finalReason == null || finalReason.isEmpty) {

              finalReason =

                  (updatedAsset['issue_detail'] ?? updatedAsset['issueDetail'])?.toString();

            }



            if (finalImages.isEmpty) {

              final rawImages =

                  updatedAsset['report_images'] ?? updatedAsset['reportImages'];

              if (rawImages != null && rawImages.toString().isNotEmpty) {

                finalImages =

                    rawImages.toString().split(',').where((s) => s.isNotEmpty).toList();

              }

            }

          }



          // Assign to State

          reporterName = finalReporter ?? 'ไม่ระบุ';

          reportReason = finalReason;

          reportImages = finalImages;



          if (hasReportDoc &&

              FirebaseService.reportStatusToCode(fetchedLatestReportStatus) == 4) {

            if (fetchedFailedReason != null &&

                fetchedFailedReason!.trim().isNotEmpty) {

              failedReason = fetchedFailedReason;

            }

            if (fetchedFailedImage != null &&

                fetchedFailedImage!.trim().isNotEmpty) {

              failedImage = fetchedFailedImage;

            }

            if (fetchedFailedByName != null &&

                fetchedFailedByName!.trim().isNotEmpty) {

              failedByName = fetchedFailedByName;

            }

          }

        });



        // Reload logs

        _loadCheckLogs();



        // รีเฟรชข้อมูลตัวเราเองจาก Firestore (เพื่อให้ชื่อล่าสุดแสดงผลถูกต้อง)

        ApiService().refreshCurrentUser().then((_) {

          if (mounted) setState(() {}); // Re-build to show update if needed

        });

      }

    } catch (e) {

      debugPrint(' Error refreshing asset data: $e');

    }

  }



  bool get hasStatusChanged => equipmentStatus != originalStatus;



  // ตรวจสอบว่าควรแสดงข้อมูลผู้ตรวจหรือไม่

  bool get shouldShowInspector =>

      (equipmentStatus == 'ปกติ' || equipmentStatus == 'อยู่ระหว่างซ่อม') &&

      (inspectorName != null && inspectorName != 'ไม่ระบุ');



  // ตรวจสอบว่าควรแสดงข้อมูลผู้แจ้งหรือไม่

  bool get shouldShowReporter =>

      (equipmentStatus == 'ชำรุด' || equipmentStatus == 'อยู่ระหว่างซ่อม');



  bool get isRepairAgainFlow =>

      equipmentStatus == 'อยู่ระหว่างซ่อม' && latestIsRepairAgain;



  bool get hasLatestDamagedAudit =>

      equipmentStatus == 'ชำรุด' &&

      ((lastDamagedAuditNote != null && lastDamagedAuditNote!.trim().isNotEmpty) ||

          (lastDamagedEvidenceImage != null &&

              lastDamagedEvidenceImage!.trim().isNotEmpty));



  bool get shouldPreferDamagedAuditSection {

    if (!hasLatestDamagedAudit) return false;

    if (latestDamagedAuditAt == null) return true;

    if (latestReportAt == null) return true;

    return latestDamagedAuditAt!.isAfter(latestReportAt!);

  }



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



      await FirebaseService().updateAsset(updateId, {

        'asset_image_url': newImageUrl,

      });



      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('ลบรูปภาพสำเร็จ'),

            backgroundColor: Colors.green,

          ),

        );

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

        if (path.startsWith('http') || path.startsWith('https')) {

          // เป็น URL อยู่แล้ว ไม่ต้องอัปโหลดใหม่

          finalUrls.add(path);

        } else {

          // เป็น local file path -> ต้องอัปโหลดไป Firebase Storage

          final file = File(path);

          final assetId = widget.equipment['asset_id']?.toString() ??

              widget.equipment['id']?.toString() ??

              'temp_${DateTime.now().millisecondsSinceEpoch}';

          final uploadedUrl = await FirebaseService().uploadAssetImage(file, assetId);



          if (uploadedUrl != null) {

            finalUrls.add(uploadedUrl);

          } else {

            debugPrint(' Failed to upload: $path');

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



      // อัพเดต asset กับ Firestore

      final updateId =

          widget.equipment['asset_id']?.toString() ??

          widget.equipment['id']?.toString() ??

          '';



      await FirebaseService().updateAsset(updateId, {

        'asset_image_url': finalUrls.join(','),

      });



      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('อัปโหลดรูปภาพสำเร็จ'),

            backgroundColor: Colors.green,

          ),

        );

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



  // Dynamic Workflow Dialog (Audit or Repair)

  void _showStatusDialog() {

    // 1. Convert current status to Int safely

    int currentStatusInt = 1; // Default Normal

    if (equipmentStatus == 'ชำรุด') {

      currentStatusInt = 2;

    } else if (equipmentStatus == 'รอดำเนินการ') {

      currentStatusInt = 3;

    } else if (equipmentStatus == 'อยู่ระหว่างซ่อม') {

      currentStatusInt = 3;

    } else if (equipmentStatus == 'ซ่อมไม่ได้') {

      currentStatusInt = 4;

    }



    // 2. Dispatch based on Status

    debugPrint("DEBUG: StatusDialog - Status: $equipmentStatus, Int: $currentStatusInt");

    if (currentStatusInt == 2) {

      // Case: Damaged -> Start Repair (Status 3)

      _showStartRepairDialog();

    } else if (currentStatusInt == 3) {

      // Case: Repairing -> Done (1) or Failed (4)

      _showFinishRepairDialog();

    } else {

      // Case: Normal/Other -> Audit (Status 1, 2 check)

      _showAuditDialog();

    }

  }



  // --- Workflow 1: Audit (Standard Check) ---

  void _showAuditDialog() {

    bool isRepairVerification = false;

    String tempStatusText = equipmentStatus == 'ปกติ' ? 'ชำรุด' : equipmentStatus;



    final TextEditingController noteController = TextEditingController();

    File? evidenceImage;

    final String currentUserName = ApiService().currentUser?['fullname'] ?? 'Admin';



    showDialog(

      context: context,

      builder: (context) {

        return StatefulBuilder(

          builder: (ctx, setDialogState) {

            final Color primaryColor =

                isRepairVerification ? const Color(0xFF5593E4) : const Color(0xFF3D7BC4);

            final Color gradientStartColor =

                isRepairVerification ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD);



            final bool isDamagedSelected =

                !isRepairVerification && tempStatusText.contains('ชำรุด');



            final Color headerPrimaryColor = isRepairVerification

                ? primaryColor

                : (isDamagedSelected ? Colors.red.shade700 : primaryColor);



            final Color headerGradientStartColor = isRepairVerification

                ? gradientStartColor

                : (isDamagedSelected ? Colors.red.shade400 : gradientStartColor);



            return AlertDialog(

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

              titlePadding: EdgeInsets.zero,

              title: ClipRRect(

                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

                child: Container(

                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(

                    gradient: LinearGradient(

                      colors: [headerGradientStartColor, headerPrimaryColor],

                      begin: Alignment.topLeft,

                      end: Alignment.bottomRight,

                    ),

                  ),

                  child: Row(

                    children: [

                      Container(

                        padding: const EdgeInsets.all(10),

                        decoration: BoxDecoration(

                          color: Colors.white.withOpacity(0.2),

                          borderRadius: BorderRadius.circular(12),

                        ),

                        child: Icon(

                          isRepairVerification ? Icons.fact_check_rounded : Icons.assignment_turned_in_rounded,

                          color: Colors.white,

                          size: 28,

                        ),

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              isRepairVerification ? 'ตรวจสอบผลการซ่อม' : 'ตรวจสอบครุภัณฑ์',

                              style: const TextStyle(

                                color: Colors.white,

                                fontSize: 20,

                                fontWeight: FontWeight.bold,

                              ),

                            ),

                            Text(

                              isRepairVerification

                                  ? 'ยืนยันความเรียบร้อยหลังการซ่อม'

                                  : 'บันทึกสถานะการใช้งานปัจจุบัน',

                              style: TextStyle(

                                color: Colors.white.withOpacity(0.8),

                                fontSize: 13,

                              ),

                            ),

                          ],

                        ),

                      ),

                    ],

                  ),

                ),

              ),

              content: SingleChildScrollView(

                child: Padding(

                  padding: const EdgeInsets.all(20),

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [

                      // Inspector Block (Original Block Design)

                      Container(

                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

                        decoration: BoxDecoration(

                          color: Colors.grey.shade50,

                          borderRadius: BorderRadius.circular(14),

                          border: Border.all(color: Colors.grey.shade200),

                        ),

                        child: Row(

                          children: [

                            Container(

                              padding: const EdgeInsets.all(8),

                              decoration: BoxDecoration(

                                color: primaryColor.withOpacity(0.1),

                                borderRadius: BorderRadius.circular(8),

                              ),

                              child: Icon(

                                Icons.person_rounded,

                                size: 18,

                                color: primaryColor,

                              ),

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(

                                    'ผู้ตรวจสอบ',

                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),

                                  ),

                                  Text(

                                    currentUserName,

                                    maxLines: 1,

                                    overflow: TextOverflow.ellipsis,

                                    style: const TextStyle(

                                      color: Colors.black87,

                                      fontSize: 14,

                                      fontWeight: FontWeight.bold,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                          ],

                        ),

                      ),

                      const SizedBox(height: 24),



                      const Text(

                        'เลือกผลการตรวจสอบ',

                        style: TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 16,

                          color: Color(0xFF333333),

                        ),

                      ),

                      const SizedBox(height: 12),



                      // Option 2: Damaged (Only shown for Regular Audit)

                      if (!isRepairVerification) ...[

                        const SizedBox(height: 12),

                        GestureDetector(

                          onTap: () => setDialogState(() => tempStatusText = 'ชำรุด'),

                          child: AnimatedContainer(

                            duration: const Duration(milliseconds: 200),

                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(

                              color: tempStatusText == 'ชำรุด' ? Colors.red.shade50 : Colors.grey.shade50,

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(

                                color: tempStatusText == 'ชำรุด' ? Colors.red.shade400 : Colors.grey.shade300,

                                width: tempStatusText == 'ชำรุด' ? 2 : 1,

                              ),

                            ),

                            child: Row(

                              children: [

                                Container(

                                  padding: const EdgeInsets.all(10),

                                  decoration: BoxDecoration(

                                    color: tempStatusText == 'ชำรุด' ? Colors.red.shade100 : Colors.grey.shade200,

                                    borderRadius: BorderRadius.circular(12),

                                  ),

                                  child: Icon(

                                    Icons.error_outline_rounded,

                                    color: tempStatusText == 'ชำรุด' ? Colors.red.shade700 : Colors.grey.shade600,

                                    size: 28,

                                  ),

                                ),

                                const SizedBox(width: 12),

                                const Expanded(

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      Text('ชำรุด / เสียหาย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

                                      Text('พบปัญหา โปรดส่งซ่อมระบุสาเหตุ', style: TextStyle(color: Colors.grey, fontSize: 12)),

                                    ],

                                  ),

                                ),

                                Icon(

                                  tempStatusText == 'ชำรุด' ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,

                                  color: tempStatusText == 'ชำรุด' ? Colors.red.shade700 : Colors.grey.shade400,

                                ),

                              ],

                            ),

                          ),

                        ),

                      ],



                      const SizedBox(height: 24),

                      const Divider(height: 1, thickness: 1),

                      const SizedBox(height: 24),



                      if (!isRepairVerification) ...[

                        Row(

                          children: [

                            Icon(

                              Icons.camera_alt,

                              color: isDamagedSelected

                                  ? Colors.red.shade700

                                  : primaryColor,

                              size: 20,

                            ),

                            const SizedBox(width: 8),

                            Text(

                              'หลักฐานภาพถ่าย',

                              style: TextStyle(

                                fontWeight: FontWeight.bold,

                                fontSize: 14,

                                color: isDamagedSelected

                                    ? Colors.red

                                    : primaryColor,

                              ),

                            ),

                            if (isDamagedSelected)

                              const Text(' *', style: TextStyle(color: Colors.red)),

                          ],

                        ),

                        const SizedBox(height: 8),

                        GestureDetector(

                          onTap: () async {

                            final source = await showModalBottomSheet<ImageSource>(

                              context: context,

                              shape: const RoundedRectangleBorder(

                                borderRadius: BorderRadius.vertical(

                                  top: Radius.circular(20),

                                ),

                              ),

                              builder: (context) => Container(

                                padding: const EdgeInsets.all(20),

                                child: Column(

                                  mainAxisSize: MainAxisSize.min,

                                  children: [

                                    const Text(

                                      'เลือกแหล่งที่มาของรูปภาพ',

                                      style: TextStyle(

                                        fontSize: 18,

                                        fontWeight: FontWeight.bold,

                                      ),

                                    ),

                                    const SizedBox(height: 20),

                                    ListTile(

                                      leading: const Icon(Icons.camera_alt),

                                      title: const Text('ถ่ายรูป'),

                                      onTap: () => Navigator.pop(

                                        context,

                                        ImageSource.camera,

                                      ),

                                    ),

                                    ListTile(

                                      leading: const Icon(Icons.photo_library),

                                      title: const Text('เลือกจากแกลเลอรี่'),

                                      onTap: () => Navigator.pop(

                                        context,

                                        ImageSource.gallery,

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                            );



                            if (source != null) {

                              final picked =

                                  await ImagePicker().pickImage(source: source);

                              if (picked != null && ctx.mounted) {

                                setDialogState(

                                  () => evidenceImage = File(picked.path),

                                );

                              }

                            }

                          },

                          child: Container(

                            height: 140,

                            decoration: BoxDecoration(

                              color: evidenceImage == null

                                  ? Colors.grey.shade100

                                  : Colors.transparent,

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: Colors.grey.shade300),

                            ),

                            child: evidenceImage == null

                                ? const Center(

                                    child: Icon(

                                      Icons.add_a_photo,

                                      size: 50,

                                      color: Colors.grey,

                                    ),

                                  )

                                : Image.file(

                                    evidenceImage!,

                                    fit: BoxFit.contain,

                                  ),

                          ),

                        ),

                        const SizedBox(height: 24),

                        const Divider(height: 1, thickness: 1),

                        const SizedBox(height: 24),

                      ],



                      // Notes Field

                      Row(

                        children: [

                          Icon(

                            Icons.sticky_note_2_rounded,

                            color: isDamagedSelected

                                ? Colors.red.shade700

                                : primaryColor,

                            size: 20,

                          ),

                          const SizedBox(width: 8),

                          Text(

                            'หมายเหตุ (ถ้ามี)',

                            style: TextStyle(

                              fontWeight: FontWeight.bold,

                              fontSize: 14,

                              color: isDamagedSelected

                                  ? Colors.red.shade700

                                  : null,

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 10),

                      TextField(

                        controller: noteController,

                        maxLines: 2,

                        decoration: InputDecoration(

                          hintText: isRepairVerification

                              ? 'ระบุความเห็นหลังการซ่อม (ถ้ามี)...'

                              : 'บันทึกสถานะเพิ่มเติม (ถ้ามี)...',

                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),

                          filled: true,

                          fillColor: Colors.grey.shade50,

                          contentPadding: const EdgeInsets.all(16),

                          border: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(14),

                            borderSide: BorderSide(color: Colors.grey.shade300),

                          ),

                          enabledBorder: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(14),

                            borderSide: BorderSide(

                              color: isDamagedSelected

                                  ? Colors.red.shade200

                                  : Colors.grey.shade200,

                            ),

                          ),

                          focusedBorder: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(14),

                            borderSide: BorderSide(

                              color: isDamagedSelected

                                  ? Colors.red.shade700

                                  : primaryColor,

                              width: 2,

                            ),

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              ),

              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

              actions: [

                TextButton(

                  onPressed: () => Navigator.pop(context),

                  child: Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),

                ),

                const SizedBox(width: 8),

                ConstrainedBox(

                  constraints: const BoxConstraints(minWidth: 160),

                  child: ElevatedButton(

                    onPressed: () {

                      String finalStatus = tempStatusText;

                      String auditNote = noteController.text.trim();



                      if (isRepairVerification) {

                        finalStatus = 'ปกติ';

                      }



                      if (!isRepairVerification &&

                          finalStatus.contains('ชำรุด') &&

                          evidenceImage == null) {

                        ScaffoldMessenger.of(context).showSnackBar(

                          const SnackBar(content: Text('กรุณาแนบรูปหลักฐาน')),

                        );

                        return;

                      }



                      _saveAuditLog(finalStatus, auditNote, ctx, evidenceImage: evidenceImage);

                    },

                    style: ElevatedButton.styleFrom(

                      backgroundColor: tempStatusText.contains('ชำรุด')

                          ? Colors.red.shade600

                          : primaryColor,

                      padding: const EdgeInsets.symmetric(

                        vertical: 14,

                        horizontal: 10,

                      ),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

                      elevation: 0,

                    ),

                    child: const FittedBox(

                      fit: BoxFit.scaleDown,

                      child: Text(

                        'ยืนยันบันทึกข้อมูล',

                        maxLines: 1,

                        style: TextStyle(

                          color: Colors.white,

                          fontWeight: FontWeight.bold,

                          fontSize: 15,

                        ),

                      ),

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



  // --- Workflow 2: Start Repair (0 -> 3) ---

  void _showStartRepairDialog() async {

    // รีเฟรชอีกรอบก่อนเปิด Dialog เพื่อความชัวร์ (เผื่อเพิ่งเปลี่ยนชื่อมา)

    await ApiService().refreshCurrentUser();

    final String currentUserName = ApiService().currentUser?['fullname'] ?? 'Admin';



    if (!mounted) return;



    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

          contentPadding: EdgeInsets.zero,

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              // Header

              Container(

                width: double.infinity,

                padding: const EdgeInsets.symmetric(vertical: 20),

                decoration: BoxDecoration(

                  color: Colors.orange.shade50,

                  borderRadius: const BorderRadius.only(

                    topLeft: Radius.circular(24),

                    topRight: Radius.circular(24),

                  ),

                ),

                child: Column(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(12),

                      decoration: const BoxDecoration(

                        color: Colors.white,

                        shape: BoxShape.circle,

                      ),

                      child: Icon(

                        Icons.build_circle_rounded,

                        color: Colors.orange.shade700,

                        size: 40,

                      ),

                    ),

                    const SizedBox(height: 12),

                    Text(

                      'เริ่มดำเนินการซ่อม',

                      style: TextStyle(

                        fontSize: 20,

                        fontWeight: FontWeight.bold,

                        color: Colors.orange.shade800,

                      ),

                    ),

                  ],

                ),

              ),



              Padding(

                padding: const EdgeInsets.all(24),

                child: Column(

                  children: [

                    const Text(

                      'คุณต้องการเปลี่ยนสถานะเป็น\n"กำลังดำเนินการซ่อม" ใช่หรือไม่?',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        fontSize: 16,

                        color: Colors.black87,

                        height: 1.5,

                      ),

                    ),

                    const SizedBox(height: 24),



                    // Responsible Person Card

                    Container(

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(

                        color: Colors.grey.shade50,

                        borderRadius: BorderRadius.circular(16),

                        border: Border.all(color: Colors.grey.shade200),

                      ),

                      child: Row(

                        children: [

                          CircleAvatar(

                            backgroundColor: Colors.white,

                            radius: 20,

                            child: Icon(Icons.person, color: Colors.orange.shade700),

                          ),

                          const SizedBox(width: 12),

                          Expanded(

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                Text(

                                  'ผู้รับผิดชอบงาน',

                                  style: TextStyle(

                                    fontSize: 12,

                                    color: Colors.grey.shade600,

                                  ),

                                ),

                                Text(

                                  currentUserName,

                                  style: const TextStyle(

                                    fontSize: 16,

                                    fontWeight: FontWeight.bold,

                                    color: Colors.black87,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              ),



              // Actions

              Padding(

                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),

                child: Row(

                  children: [

                    Expanded(

                      child: TextButton(

                        onPressed: () => Navigator.pop(context),

                        style: TextButton.styleFrom(

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          backgroundColor: Colors.grey.shade100,

                          shape: RoundedRectangleBorder(

                            borderRadius: BorderRadius.circular(12),

                          ),

                        ),

                        child: Text(

                          'ยกเลิก',

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: Colors.grey.shade700,

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(width: 12),

                    Expanded(

                      child: ElevatedButton(

                        onPressed: () => _handleStatusChange(3, '', 'อยู่ระหว่างซ่อม', context),

                        style: ElevatedButton.styleFrom(

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          backgroundColor: Colors.orange.shade700,

                          elevation: 0,

                          shape: RoundedRectangleBorder(

                            borderRadius: BorderRadius.circular(12),

                          ),

                        ),

                        child: const Text(

                          'ยืนยัน',

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: Colors.white,

                          ),

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        );

      },

    );

  }



  // --- Workflow 3: Finish Repair (3 -> 1 or 4) ---

  void _showFinishRepairDialog() async {

    // Keep the refresh logic as it helps with data sync

    await ApiService().refreshCurrentUser();



    String actionParams = 'success'; // success, fail

    final TextEditingController noteController = TextEditingController();

    File? evidenceImage;



    if (!mounted) return;



    showDialog(

      context: context,

      builder: (context) {

        return StatefulBuilder(

          builder: (ctx, setDialogState) {

            return AlertDialog(

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

              titlePadding: EdgeInsets.zero,

              title: ClipRRect(

                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

                child: Container(

                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(

                    color: actionParams == 'success'

                        ? const Color(0xFF4CAF50)

                        : Colors.grey.shade600,

                  ),

                  child: Row(

                    children: [

                      Container(

                        padding: const EdgeInsets.all(10),

                        decoration: BoxDecoration(

                          color: Colors.white.withOpacity(0.3),

                          borderRadius: BorderRadius.circular(12),

                        ),

                        child: const Icon(Icons.build_circle, color: Colors.white, size: 32),

                      ),

                      const SizedBox(width: 12),

                      const Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              'ปิดงานซ่อมบำรุง',

                              style: TextStyle(

                                color: Colors.white,

                                fontSize: 20,

                                fontWeight: FontWeight.bold,

                              ),

                            ),

                            Text(

                              'บันทึกผลการดำเนินการ',

                              style: TextStyle(

                                color: Colors.white70,

                                fontSize: 13,

                              ),

                            ),

                          ],

                        ),

                      ),

                    ],

                  ),

                ),

              ),

              content: SingleChildScrollView(

                child: Padding(

                  padding: const EdgeInsets.all(20),

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [

                      const Text(

                        'เลือกผลการซ่อม',

                        style: TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 16,

                          color: Color(0xFF333333),

                        ),

                      ),

                      const SizedBox(height: 12),



                      GestureDetector(

                        onTap: () => setDialogState(() => actionParams = 'success'),

                        child: AnimatedContainer(

                          duration: const Duration(milliseconds: 200),

                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(

                            color: actionParams == 'success' ? Colors.green.shade50 : Colors.grey.shade50,

                            borderRadius: BorderRadius.circular(16),

                            border: Border.all(

                              color: actionParams == 'success' ? Colors.green.shade400 : Colors.grey.shade300,

                              width: actionParams == 'success' ? 2 : 1,

                            ),

                          ),

                          child: Row(

                            children: [

                              Container(

                                padding: const EdgeInsets.all(10),

                                decoration: BoxDecoration(

                                  color: actionParams == 'success' ? Colors.green.shade100 : Colors.grey.shade200,

                                  borderRadius: BorderRadius.circular(12),

                                ),

                                child: Icon(

                                  Icons.check_circle,

                                  color: actionParams == 'success' ? Colors.green.shade700 : Colors.grey.shade600,

                                  size: 28,

                                ),

                              ),

                              const SizedBox(width: 12),

                              const Expanded(

                                child: Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    Text('ซ่อมเสร็จสิ้น', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

                                    Text('อุปกรณ์พร้อมใช้งานได้ปกติ', style: TextStyle(color: Colors.grey, fontSize: 12)),

                                  ],

                                ),

                              ),

                              Icon(actionParams == 'success' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: actionParams == 'success' ? Colors.green.shade700 : Colors.grey.shade400),

                            ],

                          ),

                        ),

                      ),

                      const SizedBox(height: 12),



                      GestureDetector(

                        onTap: () => setDialogState(() => actionParams = 'fail'),

                        child: AnimatedContainer(

                          duration: const Duration(milliseconds: 200),

                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(

                            color: actionParams == 'fail' ? Colors.red.shade50 : Colors.grey.shade50,

                            borderRadius: BorderRadius.circular(16),

                            border: Border.all(

                              color: actionParams == 'fail' ? Colors.red.shade400 : Colors.grey.shade300,

                              width: actionParams == 'fail' ? 2 : 1,

                            ),

                          ),

                          child: Row(

                            children: [

                              Container(

                                padding: const EdgeInsets.all(10),

                                decoration: BoxDecoration(

                                  color: actionParams == 'fail' ? Colors.red.shade100 : Colors.grey.shade200,

                                  borderRadius: BorderRadius.circular(12),

                                ),

                                child: Icon(

                                  Icons.cancel,

                                  color: actionParams == 'fail' ? Colors.red.shade700 : Colors.grey.shade600,

                                  size: 28,

                                ),

                              ),

                              const SizedBox(width: 12),

                              const Expanded(

                                child: Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    Text('ซ่อมไม่ได้', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

                                    Text('แนะนำจำหน่ายออก', style: TextStyle(color: Colors.grey, fontSize: 12)),

                                  ],

                                ),

                              ),

                              Icon(actionParams == 'fail' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: actionParams == 'fail' ? Colors.red.shade700 : Colors.grey.shade400),

                            ],

                          ),

                        ),

                      ),



                      const SizedBox(height: 20),

                      const Divider(),

                      const SizedBox(height: 16),



                      if (actionParams == 'fail') ...[

                        Row(

                          children: [

                            Icon(Icons.description, color: Colors.red.shade700, size: 20),

                            const SizedBox(width: 8),

                            const Text('เหตุผลที่ซ่อมไม่ได้', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),

                            const Text(' *', style: TextStyle(color: Colors.red)),

                          ],

                        ),

                        const SizedBox(height: 8),

                        TextField(

                          controller: noteController,

                          maxLines: 3,

                          decoration: InputDecoration(

                            hintText: 'ระบุสาเหตุที่ไม่สามารถซ่อมได้...',

                            hintStyle: TextStyle(color: Colors.grey.shade400),

                            filled: true,

                            fillColor: Colors.grey.shade50,

                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),

                          ),

                        ),

                        const SizedBox(height: 16),

                        Row(

                          children: [

                            Icon(Icons.camera_alt, color: Colors.red.shade700, size: 20),

                            const SizedBox(width: 8),

                            const Text('หลักฐานภาพถ่าย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),

                            const Text(' *', style: TextStyle(color: Colors.red)),

                          ],

                        ),

                        const SizedBox(height: 8),

                        GestureDetector(

                          onTap: () async {

                            final source = await showModalBottomSheet<ImageSource>(

                              context: context,

                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),

                              builder: (context) => Container(

                                padding: const EdgeInsets.all(20),

                                child: Column(

                                  mainAxisSize: MainAxisSize.min,

                                  children: [

                                    const Text('เลือกแหล่งที่มาของรูปภาพ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                    const SizedBox(height: 20),

                                    ListTile(

                                      leading: const Icon(Icons.camera_alt),

                                      title: const Text('ถ่ายรูป'),

                                      onTap: () => Navigator.pop(context, ImageSource.camera),

                                    ),

                                    ListTile(

                                      leading: const Icon(Icons.photo_library),

                                      title: const Text('เลือกจากแกลเลอรี่'),

                                      onTap: () => Navigator.pop(context, ImageSource.gallery),

                                    ),

                                  ],

                                ),

                              ),

                            );

                            if (source != null) {

                              final picked = await ImagePicker().pickImage(source: source);

                              if (picked != null && ctx.mounted) {

                                setDialogState(() => evidenceImage = File(picked.path));

                              }

                            }

                          },

                          child: Container(

                            height: 140,

                            decoration: BoxDecoration(

                              color: evidenceImage == null ? Colors.grey.shade100 : Colors.transparent,

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: Colors.grey.shade300),

                            ),

                            child: evidenceImage == null

                                ? const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey))

                                : Image.file(evidenceImage!, fit: BoxFit.contain),

                          ),

                        ),

                      ] else ...[

                        Row(

                          children: [

                            Icon(Icons.note_alt, color: Colors.green.shade700, size: 20),

                            const SizedBox(width: 8),

                            const Text('หมายเหตุ (ถ้ามี)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),

                          ],

                        ),

                        const SizedBox(height: 8),

                        TextField(

                          controller: noteController,

                          maxLines: 3,

                          decoration: InputDecoration(

                            hintText: 'บันทึกหมายเหตุเพิ่มเติม (ถ้ามี)...',

                            hintStyle: TextStyle(color: Colors.grey.shade400),

                            filled: true,

                            fillColor: Colors.grey.shade50,

                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),

                          ),

                        ),

                        const SizedBox(height: 16),

                        Row(

                          children: [

                            Icon(Icons.camera_alt, color: Colors.green.shade700, size: 20),

                            const SizedBox(width: 8),

                            const Text(

                              'รูปภาพหลังซ่อม (ถ้ามี)',

                              style: TextStyle(

                                fontWeight: FontWeight.bold,

                                fontSize: 14,

                                color: Colors.green,

                              ),

                            ),

                          ],

                        ),

                        const SizedBox(height: 8),

                        GestureDetector(

                          onTap: () async {

                            final source = await showModalBottomSheet<ImageSource>(

                              context: context,

                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),

                              builder: (context) => Container(

                                padding: const EdgeInsets.all(20),

                                child: Column(

                                  mainAxisSize: MainAxisSize.min,

                                  children: [

                                    const Text('เลือกแหล่งที่มาของรูปภาพ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                    const SizedBox(height: 20),

                                    ListTile(

                                      leading: const Icon(Icons.camera_alt),

                                      title: const Text('ถ่ายรูป'),

                                      onTap: () => Navigator.pop(context, ImageSource.camera),

                                    ),

                                    ListTile(

                                      leading: const Icon(Icons.photo_library),

                                      title: const Text('เลือกจากแกลเลอรี่'),

                                      onTap: () => Navigator.pop(context, ImageSource.gallery),

                                    ),

                                  ],

                                ),

                              ),

                            );

                            if (source != null) {

                              final picked = await ImagePicker().pickImage(source: source);

                              if (picked != null && ctx.mounted) {

                                setDialogState(() => evidenceImage = File(picked.path));

                              }

                            }

                          },

                          child: Container(

                            height: 140,

                            decoration: BoxDecoration(

                              color: evidenceImage == null ? Colors.grey.shade100 : Colors.transparent,

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: Colors.grey.shade300),

                            ),

                            child: evidenceImage == null

                                ? const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey))

                                : Image.file(evidenceImage!, fit: BoxFit.contain),

                          ),

                        ),

                      ],

                    ],

                  ),

                ),

              ),

              actions: [

                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),

                ElevatedButton(

                  onPressed: () async {

                    if (actionParams == 'fail') {

                      if (noteController.text.isEmpty || evidenceImage == null) {

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')));

                        return;

                      }

                      await _handleFailedRepair(noteController.text, evidenceImage!, context);

                    } else {

                      await _handleStatusChange(

                        1,

                        noteController.text,

                        'ปกติ',

                        context,

                        evidenceImage: evidenceImage,

                        isFinishRepair: true,

                      );

                    }

                  },

                  style: ElevatedButton.styleFrom(backgroundColor: actionParams == 'success' ? Colors.green : Colors.red),

                  child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),

                ),

              ],

            );

          },

        );

      },

    );

  }



  // --- Logic Helpers ---

  Future<void> _handleStatusChange(

    int newStatus,

    String note,

    String newStatusText,

    BuildContext dialogContext, {

    File? evidenceImage,

    bool isFinishRepair = false,

  }) async {

    // Reuse existing logic, generalized

    try {

      final currentUserUid = ApiService().currentUser?['uid'] ?? 'unknown_uid';

      final currentUserName =

          ApiService().currentUser?['fullname'] ?? 'Unknown Admin';

      final assetIdStr = widget.equipment['asset_id']?.toString() ??

          widget.equipment['id'].toString();



        String? evidenceUrl;

        if (evidenceImage != null) {

          if (newStatus == 2) {

            evidenceUrl =

                await FirebaseService().uploadReportImage(evidenceImage, assetIdStr);

          } else {

            evidenceUrl =

                await FirebaseService().uploadRepairImage(evidenceImage, assetIdStr);

          }

        }

        

        // Audit Log (strict minimal schema): only status 1 or 2

        if ((newStatus == 1 || newStatus == 2) && !isFinishRepair) {

          await FirebaseService().createAuditLog({

            'asset_id': assetIdStr,

            'auditor_id': currentUserUid,

            'auditor_name': currentUserName,

            'audit_status': newStatus,

            'audited_image_url': evidenceUrl ?? '',

            'audited_remark': note.trim(),

          });

        }



        // ⭐ If damaged from audit -> also create a report_history record

        if (newStatus == 2) {

          await FirebaseService().createReport({

            'asset_id': assetIdStr,

            'reporter_id': currentUserUid,

            'reporter_name': currentUserName,

            'report_remark': note,

            if (evidenceUrl != null && evidenceUrl.isNotEmpty)

              'report_image_url': evidenceUrl,

            'reported_at': FieldValue.serverTimestamp(),

            'report_status': 1,

          }, shouldCreateAuditLog: false);

        }



        // ⭐ If start repairing -> update latest report_history for this asset

        // start_repair_at / worker_id should be set ONLY when confirming start repair.

        if (newStatus == 3) {

          final updateData = {

            'report_status': 2,

            'worker_id': currentUserUid,

            'worker_name': currentUserName,

            'start_repair_at': FieldValue.serverTimestamp(),

          };



          if (latestReportDocId != null && latestReportDocId!.trim().isNotEmpty) {

            try {

              final ref = FirebaseFirestore.instance

                  .collection('reports_history')

                  .doc(latestReportDocId);

              final snap = await ref.get();

              final existing = snap.data();

              final existingName = existing?['reporter_name']?.toString();

              if (existingName == null || existingName.trim().isEmpty) {

                final fallbackName = (reporterName != null && reporterName!.trim().isNotEmpty)

                    ? reporterName!.trim()

                    : currentUserName;

                updateData['reporter_name'] = fallbackName;



                final existingId = existing?['reporter_id']?.toString();

                updateData['reporter_id'] = (existingId != null && existingId.trim().isNotEmpty)

                    ? existingId.trim()

                    : currentUserUid;

              }



              await ref.update(updateData);

            } catch (_) {

              await FirebaseFirestore.instance

                  .collection('reports_history')

                  .doc(latestReportDocId)

                  .update(updateData);

            }

          } else {

            await FirebaseService().updateLatestReportForAsset(assetIdStr, updateData);

          }

        }



        // ⭐ If finishing repair successfully -> update latest report_history

        if (isFinishRepair && newStatus == 1) {

          final updateData = <String, dynamic>{

            'report_status': 3,

            'finished_at': FieldValue.serverTimestamp(),

            'worker_id': currentUserUid,

            'worker_name': currentUserName,

          };

          updateData['finished_remark'] = note.trim();



          updateData['remark_broken'] = FieldValue.delete();

          updateData['broken_image_url'] = FieldValue.delete();

          updateData['remark_completed'] = FieldValue.delete();



          updateData['finished_image_url'] = evidenceUrl?.trim() ?? '';



          if (latestReportDocId != null && latestReportDocId!.trim().isNotEmpty) {

            await FirebaseFirestore.instance

                .collection('reports_history')

                .doc(latestReportDocId)

                .update(updateData);

          } else {

            try {

              // Avoid composite-index requirement by not combining where(...) + where(...) + limit(...).

              final snapshot = await FirebaseFirestore.instance

                  .collection('reports_history')

                  .where('asset_id', isEqualTo: assetIdStr)

                  .get();



              final repairingDocs = snapshot.docs

                  .where((d) {

                    final data = d.data();

                    final s = FirebaseService.reportStatusToCode(data['report_status']);

                    return s == 2;

                  })

                  .toList();

              repairingDocs.sort((a, b) => b.id.compareTo(a.id));



              if (repairingDocs.isNotEmpty) {

                await repairingDocs.first.reference.update(updateData);

              } else {

                await FirebaseService().updateLatestReportForAsset(

                  assetIdStr,

                  updateData,

                );

              }

            } catch (_) {

              await FirebaseService().updateLatestReportForAsset(assetIdStr, updateData);

            }

          }

        }



        // Update Asset

        await FirebaseService().updateAsset(assetIdStr, {

          'asset_status': newStatus,

          'audited_at': DateTime.now(),

            if (newStatus == 3) ...{

              'repairer_id': currentUid, // Save UID for locking

              'auditor_name': currentUserName, // Use fullname consistently

            },

         });



        if (!mounted) return;

        Navigator.pop(dialogContext); // Close dialog

        setState(() {

          if (newStatus == 1) {

            equipmentStatus = 'ปกติ';

          } else if (newStatus == 2) {

            equipmentStatus = 'ชำรุด';

          } else if (newStatus == 3) {

            equipmentStatus = 'อยู่ระหว่างซ่อม';

          } else if (newStatus == 4) {

            equipmentStatus = 'ซ่อมไม่ได้';

          }



          // Keep header/status card in sync immediately

          originalStatus = equipmentStatus;

        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(

            content: Text('บันทึกสถานะเรียบร้อย'), backgroundColor: Colors.green));

        _loadCheckLogs();

    } catch (e) {

      debugPrint("Error: $e");



      if (!mounted) return;



      // Close the status dialog if it's still open.

      final nav = Navigator.of(dialogContext);

      if (nav.canPop()) {

        nav.pop();

      }



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text('บันทึกข้อมูลไม่ได้: $e'),

          backgroundColor: Colors.red,

        ),

      );

    }

  }



  Future<void> _handleFailedRepair(String note, File image, BuildContext dialogContext) async {

     try {

       // Upload Image

       final assetIdStr = widget.equipment['asset_id']?.toString() ?? widget.equipment['id'].toString();

       String? imgUrl = await FirebaseService().uploadRepairImage(image, assetIdStr);



       final currentUserUid = ApiService().currentUser?['uid'] ?? 'unknown_uid';

       final currentUserName =

           ApiService().currentUser?['fullname'] ?? 'Unknown Admin';



        // ⭐ Update latest report_history for this asset

        // Canonical close-job fields (used for both completed=3 and cancelled=4).

        final updateData = <String, dynamic>{

          'finished_remark': note,

          'finished_image_url': imgUrl ?? '',

          'report_status': 4,

          'finished_at': FieldValue.serverTimestamp(),

          'worker_id': currentUserUid,

          'worker_name': currentUserName,

          'remark_broken': FieldValue.delete(),

          'broken_image_url': FieldValue.delete(),

          'remark_completed': FieldValue.delete(),

        };



        if (latestReportDocId != null && latestReportDocId!.trim().isNotEmpty) {

          await FirebaseFirestore.instance

              .collection('reports_history')

              .doc(latestReportDocId)

              .update(updateData);

        } else {

          await FirebaseService().updateLatestReportForAsset(assetIdStr, updateData);

        }



        // Update Asset

        await FirebaseService().updateAsset(assetIdStr, {

          'asset_status': 4,

          'audited_at': FieldValue.serverTimestamp(),

          'condemned_at': FieldValue.serverTimestamp(),

          'repairer_id': null,

          'auditor_name': currentUserName,

        });

        

         if (!mounted) return;

          Navigator.pop(dialogContext);

          setState(() => equipmentStatus = 'ซ่อมไม่ได้');

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกผลซ่อมไม่ได้เรียบร้อย'), backgroundColor: Colors.grey));

          _loadCheckLogs();

     } catch (e) {

       debugPrint("Fail Error: $e");

       if (!mounted) return;



       final nav = Navigator.of(dialogContext);

       if (nav.canPop()) {

         nav.pop();

       }



       ScaffoldMessenger.of(context).showSnackBar(

         SnackBar(

           content: Text('บันทึกข้อมูลไม่ได้: $e'),

           backgroundColor: Colors.red,

         ),

       );

     }

  }



  Future<void> _saveAuditLog(

    String statusStr,

    String note,

    BuildContext dialogContext, {

    File? evidenceImage,

  }) async {

    int sInt = 1;

    if (statusStr.contains('ชำรุด')) sInt = 2;

    if (statusStr == 'ซ่อมไม่ได้') sInt = 4;

    await _handleStatusChange(

      sInt,

      note,

      statusStr,

      dialogContext,

      evidenceImage: evidenceImage,

    );

  }



  // --- UI Component Helpers ---

  @override

  Widget build(BuildContext context) {

    Color statusColor = originalStatus == 'ปกติ'

        ? Colors.green

        : originalStatus == 'ชำรุด'

        ? Colors.red

        : originalStatus == 'ซ่อมไม่ได้'

        ? Colors.grey

        : Colors.orange;



    return PopScope(

      canPop: false,

      onPopInvokedWithResult: (didPop, result) async {

        if (didPop) return;

        Navigator.pop(context, {

          'status': equipmentStatus,

          'inspectorName': inspectorName,

          'asset_image_url': imagePaths.isNotEmpty ? imagePaths.first : null,

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

                'asset_image_url': imagePaths.isNotEmpty ? imagePaths.first : null,

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

                currentRoomName.isNotEmpty && currentRoomName != 'ไม่ระบุห้อง'

                    ? currentRoomName

                : widget.roomName,

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

            EquipmentImageSection(

              title: 'รูปภาพครุภัณฑ์',

              images: imagePaths,

              color: const Color(0xFF5593E4),

              isAdmin: isAdmin,

              isUploadingImage: isUploadingImage,

              onAddImage: _showImageSourceDialog,

              onDeleteImage: _deleteImage,

              onUploadImages: _uploadAndUpdateImage,

              onOpenImage: (img) => _showFullScreenImage(context, img),

            ),

            const SizedBox(height: 20),



            // ข้อมูลพื้นฐาน

            _buildBasicInfoSection(),

            const SizedBox(height: 20),



            // สถานะ

            // สถานะ & Action

            _buildActionSection(statusColor),

            const SizedBox(height: 20),



            // 1. ข้อมูลผู้ตรวจ (กรณีปกติ)

            if (equipmentStatus == 'ปกติ' &&

                inspectorName != null &&

                inspectorName != 'ไม่ระบุ' &&

                inspectorName != 'ยังไม่มีการตรวจสอบ') ...[

              _buildInspectorSection(),

              const SizedBox(height: 20),

            ],





            // 3. ข้อมูลผู้แจ้ง (กรณีชำรุด หรือ อยู่ระหว่างซ่อม)

            // ⭐ หากเป็น flow "ซ่อมอีกครั้ง" ให้ซ่อนการแจ้งปัญหาเดิม

            // ⭐ หากชำรุดจากการตรวจล่าสุด ให้โชว์ผลตรวจล่าสุดแทน (ไม่เอา report เก่า)

            if (equipmentStatus == 'ชำรุด' && shouldPreferDamagedAuditSection) ...[

              _buildDamagedAuditSection(),

              const SizedBox(height: 20),

            ] else if ((equipmentStatus == 'ชำรุด' ||

                    equipmentStatus == 'อยู่ระหว่างซ่อม') &&

                latestReportDocId != null &&

                latestReportDocId!.trim().isNotEmpty) ...[

              if (equipmentStatus == 'อยู่ระหว่างซ่อม' && latestIsRepairAgain)

                _buildRepairAgainSection()

              else

                _buildReporterSection(),

              const SizedBox(height: 20),

            ],



            // 4. ข้อมูลการซ่อมไม่ได้ (กรณีซ่อมไม่ได้)

            // ⭐ หากเป็น flow "ซ่อมอีกครั้ง" ให้โชว์รายละเอียดซ่อมไม่ได้ครั้งก่อนด้วย

            if (equipmentStatus == 'ซ่อมไม่ได้' ||

                (isRepairAgainFlow &&

                    failedReason != null &&

                    failedReason!.trim().isNotEmpty)) ...[

               _buildFailureDetailsSection(),

               const SizedBox(height: 20),

            ],



            // ผู้สร้าง (แสดงตลอด - ย้ายมาข้างล่าง)

            _buildCreatorSection(),

            const SizedBox(height: 20),



            // ประวัติการตรวจสอบ (เอาออกตาม request)

            // _buildInspectionHistory(),

            // const SizedBox(height: 20),





            // QR Code Section (ย้ายมาไว้ท้ายสุด)

            _buildQRCodeSection(),

          ],

        ),

      ),

    );

  }



  Widget _buildRepairAgainSection() {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.orange.shade100, width: 2),

        boxShadow: [

          BoxShadow(

            color: Colors.orange.withValues(alpha: 0.08),

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

                  color: Colors.orange.withValues(alpha: 0.15),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: Icon(

                  Icons.restart_alt,

                  color: Colors.orange.shade800,

                  size: 24,

                ),

              ),

              const SizedBox(width: 12),

              Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    'ซ่อมอีกครั้ง',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                      color: Colors.grey.shade800,

                    ),

                  ),

                  Text(

                    'เปิดรอบซ่อมใหม่',

                    style: const TextStyle(fontSize: 12, color: Colors.grey),

                  ),

                ],

              ),

            ],

          ),

          const SizedBox(height: 20),

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

            decoration: BoxDecoration(

              color: Colors.orange.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(16),

            ),

            child: Row(

              children: [

                const CircleAvatar(

                  backgroundColor: Colors.white,

                  radius: 18,

                  child: Icon(

                    Icons.person,

                    color: Colors.orange,

                    size: 20,

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        'ผู้เปิดงาน',

                        style: TextStyle(

                          fontSize: 12,

                          color: Colors.orange.shade300,

                        ),

                      ),

                      Text(

                        ApiService().getUserName(reporterName),

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(

                          fontSize: 15,

                          fontWeight: FontWeight.bold,

                          color: Colors.orange.shade900,

                          fontStyle: (reporterName != null)

                              ? FontStyle.normal

                              : FontStyle.italic,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

          if (reportReason != null && reportReason!.trim().isNotEmpty) ...[

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

                      Icon(Icons.notes, color: Colors.orange.shade600, size: 20),

                      const SizedBox(width: 8),

                      Text(

                        'เหตุผลซ่อมอีกครั้ง',

                        style: TextStyle(

                          fontSize: 14,

                          fontWeight: FontWeight.bold,

                          color: Colors.orange.shade800,

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 8),

                  Text(

                    reportReason!,

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



          if ((latestFinishedRemark != null &&

                  latestFinishedRemark!.trim().isNotEmpty) ||

              (latestFinishedImageUrl != null &&

                  latestFinishedImageUrl!.trim().isNotEmpty)) ...[

            const SizedBox(height: 12),

            Container(

              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                color: const Color(0xFF5593E4).withValues(alpha: 0.08),

                borderRadius: BorderRadius.circular(14),

                border: Border.all(color: const Color(0xFF5593E4).withValues(alpha: 0.35)),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      const Icon(Icons.check_circle, color: Color(0xFF5593E4), size: 16),

                      const SizedBox(width: 8),

                      Text(

                        'ผลปิดงานซ่อม',

                        style: TextStyle(

                          fontSize: 13,

                          fontWeight: FontWeight.bold,

                          color: const Color(0xFF1E5AA8),

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 6),

                  RichText(

                    text: TextSpan(

                      style: const TextStyle(fontSize: 13),

                      children: [

                        const TextSpan(

                          text: 'ตรวจสอบเสร็จแล้ว: ',

                          style: TextStyle(color: Color(0xFF1E5AA8)),

                        ),

                        TextSpan(

                          text: _formatFinishedAt(latestFinishedAt),

                          style: const TextStyle(color: Colors.black87),

                        ),

                      ],

                    ),

                  ),

                  if (latestFinishedRemark != null && latestFinishedRemark!.trim().isNotEmpty) ...[

                    const SizedBox(height: 4),

                    RichText(

                      text: TextSpan(

                        style: const TextStyle(fontSize: 13, height: 1.35),

                        children: [

                          const TextSpan(

                            text: 'หมายเหตุ: ',

                            style: TextStyle(color: Color(0xFF1E5AA8)),

                          ),

                          TextSpan(

                            text: latestFinishedRemark!.trim(),

                            style: const TextStyle(color: Colors.black87),

                          ),

                        ],

                      ),

                    ),

                  ],

                  if (latestFinishedImageUrl != null && latestFinishedImageUrl!.trim().isNotEmpty) ...[

                    const SizedBox(height: 12),

                    GestureDetector(

                      onTap: () => _showFullScreenImage(context, latestFinishedImageUrl!.trim()),

                      child: Container(

                        height: 200,

                        width: double.infinity,

                        decoration: BoxDecoration(

                          color: Colors.transparent,

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(color: const Color(0xFF5593E4).withValues(alpha: 0.35)),

                        ),

                        child: ClipRRect(

                          borderRadius: BorderRadius.circular(16),

                          child: Image.network(

                            latestFinishedImageUrl!.trim(),

                            fit: BoxFit.contain,

                            errorBuilder: (ctx, err, stack) => const Center(

                              child: Text('โหลดรูปภาพไม่สำเร็จ'),

                            ),

                          ),

                        ),

                      ),

                    ),

                  ],

                ],

              ),

            ),

          ],

        ],

      ),

    );

  }



  Widget _buildDamagedAuditSection() {

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

                    'ผลการตรวจล่าสุด',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                      color: Colors.grey.shade800,

                    ),

                  ),

                  const Text(

                    'ตรวจพบชำรุด/เสียหาย',

                    style: TextStyle(fontSize: 12, color: Colors.grey),

                  ),

                ],

              ),

            ],

          ),

          const SizedBox(height: 20),



          // Inspector

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

            decoration: BoxDecoration(

              color: const Color(0xFFFFF0F0),

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

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        'ผู้ตรวจสอบ',

                        style: TextStyle(

                          fontSize: 12,

                          color: Colors.red.shade300,

                        ),

                      ),

                      Text(

                        ApiService().getUserName(lastDamagedInspectorName),

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(

                          fontSize: 15,

                          fontWeight: FontWeight.bold,

                          color: Colors.red.shade900,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),



          if (lastDamagedAuditNote != null &&

              lastDamagedAuditNote!.trim().isNotEmpty) ...[

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

                        latestIsRepairAgain ? 'เหตุผลซ่อมอีกครั้ง' : 'รายละเอียด / สาเหตุ',

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

                    lastDamagedAuditNote!,

                    style: TextStyle(

                      fontSize: 14,

                      color: Colors.grey.shade800,

                    ),

                  ),

                ],

              ),

            ),

          ],



          if (lastDamagedEvidenceImage != null &&

              lastDamagedEvidenceImage!.trim().isNotEmpty) ...[

            const SizedBox(height: 12),

            Text(

              'หลักฐานภาพถ่าย',

              style: TextStyle(

                fontSize: 14,

                fontWeight: FontWeight.bold,

                color: Colors.red.shade800,

              ),

            ),

            const SizedBox(height: 10),

            GestureDetector(

              onTap: () => _showFullScreenImage(context, lastDamagedEvidenceImage!),

              child: Container(

                height: 200,

                width: double.infinity,

                decoration: BoxDecoration(

                  color: Colors.grey.shade100,

                  borderRadius: BorderRadius.circular(16),

                  border: Border.all(color: Colors.grey.shade200),

                ),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(16),

                  child: Image.network(

                    lastDamagedEvidenceImage!,

                    fit: BoxFit.contain,

                    errorBuilder: (ctx, err, stack) => const Center(

                      child: Text('โหลดรูปภาพไม่สำเร็จ'),

                    ),

                  ),

                ),

              ),

            ),

          ],

        ],

      ),

    );

  }



  Widget _buildFailureDetailsSection() {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.grey.shade300, width: 2), // Grey border

        boxShadow: [

          BoxShadow(

            color: Colors.grey.withValues(alpha: 0.1),

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

                   color: Colors.grey.withValues(alpha: 0.15),

                   borderRadius: BorderRadius.circular(10),

                 ),

                 child: Icon(Icons.report_off, color: Colors.grey.shade700, size: 24),

              ),

              const SizedBox(width: 12),

              Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    'รายละเอียดผลการซ่อม',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                      color: Colors.grey.shade800,

                    ),

                  ),

                  const Text(

                    'สถานะ: ซ่อมไม่ได้',

                     style: TextStyle(fontSize: 12, color: Colors.grey),

                  ),

                ],

              ),

            ],

          ),

          const SizedBox(height: 20),



          // Inspector Name

           Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

            decoration: BoxDecoration(

              color: Colors.grey.shade100, // Light grey background

              borderRadius: BorderRadius.circular(16),

            ),

            child: Row(

              children: [

                CircleAvatar(

                  backgroundColor: Colors.white,

                  radius: 18,

                  child: Icon(

                    Icons.person,

                    color: Colors.grey.shade600,

                    size: 20,

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        'ผู้ตรวจสอบ/ผู้ซ่อม',

                        style: TextStyle(

                          fontSize: 12,

                          color: Colors.grey.shade600,

                        ),

                      ),

                      Text(

                        inspectorName ?? 'ไม่ระบุ',

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(

                          fontSize: 15,

                          fontWeight: FontWeight.bold,

                          color: Colors.grey.shade900,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),



           const SizedBox(height: 15),



           // Reason

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

                     Icon(Icons.note_alt_outlined, color: Colors.red.shade400, size: 20),

                     const SizedBox(width: 8),

                     Text(

                       'เหตุผลที่ซ่อมไม่ได้',

                       style: TextStyle(

                         fontSize: 14,

                         fontWeight: FontWeight.bold,

                         color: Colors.red.shade800, // Red text for emphasis

                       ),

                     ),

                   ],

                 ),

                 const SizedBox(height: 8),

                 Text(

                   (failedReason != null && failedReason!.isNotEmpty) 

                      ? failedReason! 

                      : 'ไม่ได้ระบุเหตุผล',

                   style: TextStyle(

                     color: Colors.grey.shade800, 

                     fontSize: 15,

                     height: 1.5,

                   ),

                 ),

               ],

             ),

           ),



           // Evidence Image

           if (failedImage != null && failedImage!.isNotEmpty) ...[

             const SizedBox(height: 15),

             Text(

               'หลักฐานภาพถ่าย',

               style: TextStyle(

                 fontSize: 14, 

                 fontWeight: FontWeight.w600, 

                 color: Colors.grey.shade700

               ),

             ),

             const SizedBox(height: 10),

             GestureDetector(

                onTap: () => _showFullScreenImage(context, failedImage!),

                child: Container(

                   height: 200,

                   width: double.infinity,

                   decoration: BoxDecoration(

                     borderRadius: BorderRadius.circular(16),

                     border: Border.all(color: Colors.grey.shade200),

                     color: Colors.grey.shade100,

                   ),

                   child: ClipRRect(

                     borderRadius: BorderRadius.circular(16),

                     child: Image.network(

                       failedImage!,

                       fit: BoxFit.contain, // Keep aspect ratio

                       errorBuilder: (ctx, err, stack) => const Center(

                         child: Column(

                           mainAxisAlignment: MainAxisAlignment.center,

                           children: [

                             Icon(Icons.broken_image, color: Colors.grey, size: 40),

                             SizedBox(height: 8),

                             Text('โหลดรูปภาพไม่สำเร็จ', style: TextStyle(color: Colors.grey)),

                           ],

                         ),

                       ),

                     ),

                   ),

                ),

             ),

           ],

        ],

      ),

    );

  }



  Widget _buildBasicInfoSection() {

    String formatPriceDisplay(dynamic raw) {

      if (raw == null) return '-';

      String s = raw.toString().trim();

      if (s.isEmpty || s == 'null') return '-';



      // Normalize:

      // - number -> string

      // - "32,000" -> "32000"

      // - "2000,34" -> "2000.34" (decimal comma)

      final hasDot = s.contains('.');

      final commaCount = ','.allMatches(s).length;



      String normalized = s;

      if (raw is num) {

        normalized = raw.toString();

      } else if (hasDot) {

        normalized = normalized.replaceAll(',', '');

      } else if (commaCount == 1) {

        final parts = normalized.split(',');

        final dec = parts.length == 2 ? parts[1] : '';

        if (dec.length <= 2) {

          normalized = '${parts[0]}.$dec';

        } else {

          normalized = normalized.replaceAll(',', '');

        }

      } else {

        normalized = normalized.replaceAll(',', '');

      }



      final v = double.tryParse(normalized);

      if (v == null) return '-';



      final fixed = v.toStringAsFixed(2);

      final parts = fixed.split('.');

      final intPart = parts.first;

      final decPart = parts.length > 1 ? parts[1] : '00';



      final buf = StringBuffer();

      for (int i = 0; i < intPart.length; i++) {

        final left = intPart.length - i;

        buf.write(intPart[i]);

        if (left > 1 && left % 3 == 1) {

          buf.write(',');

        }

      }

      return '${buf.toString()}.$decPart';

    }



    String formatPurchaseDate(dynamic raw) {

      if (raw == null) return '-';

      const months = [

        'มกราคม',

        'กุมภาพันธ์',

        'มีนาคม',

        'เมษายน',

        'พฤษภาคม',

        'มิถุนายน',

        'กรกฎาคม',

        'สิงหาคม',

        'กันยายน',

        'ตุลาคม',

        'พฤศจิกายน',

        'ธันวาคม',

      ];



      DateTime? d;

      if (raw is Timestamp) {

        d = raw.toDate();

      } else if (raw is DateTime) {

        d = raw;

      } else {

        final s = raw.toString().trim();

        d = DateTime.tryParse(s);

        if (d == null) return s.isEmpty ? '-' : s;

      }



      final monthName = months[d.month - 1];

      final buddhistYear = d.year + 543;

      return 'วันที่ ${d.day} เดือน$monthName พ.ศ.$buddhistYear';

    }



    return Container(

      width: double.infinity, // เต็มความกว้าง

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

          // Header

          Row(

            children: [

              Icon(Icons.info_outline, color: Colors.grey.shade700, size: 24),

              const SizedBox(width: 10),

              Text(

                'รายละเอียดครุภัณฑ์',

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

            widget.equipment['asset_id'] ??

                widget.equipment['id'] ??

                'ไม่ระบุรหัส',

            const Color(0xFF5593E4),

          ),

          const Divider(height: 25),

          _buildInfoRow(

            Icons.label_important,

            'ชื่อครุภัณฑ์',

            assetName ?? '-',

            const Color(0xFFE44F5A),

          ),

          const Divider(height: 25),

          _buildInfoRow(

            Icons.category,

            'หมวดหมู่',

            widget.equipment['asset_type'] ?? widget.equipment['type'] ?? '-',

            const Color(0xFF99CD60),

          ),

          const Divider(height: 25),

          _buildInfoRow(

            Icons.calendar_month,

            'วันที่ซื้อ',

            formatPurchaseDate(widget.equipment['purchase_at'] ?? purchaseAt),

            const Color(0xFF9A2C2C),

          ),

          const Divider(height: 25),

          _buildInfoRow(

            Icons.payments_outlined,

            'ราคา',

            '${formatPriceDisplay(price)} บาท',

            Colors.teal,

          ),

          const Divider(height: 25),

          _buildInfoRow(

            Icons.room,

            'ห้อง',

            currentRoomName.isNotEmpty && currentRoomName != 'ไม่ระบุห้อง'

                ? currentRoomName

                : widget.roomName,

            const Color(0xFF9A2C2C),

          ),

        ],

      ),

    );

  }



  // Section สถานะ

  // Section สถานะ & Action

  Widget _buildActionSection(Color statusColor) {

    bool isAdmin = ApiService().currentUser?['role'] == 'admin';



    // กำหนด Text และ Icon ปุ่มตามสถานะ

    String actionLabel = 'แจ้งปัญหา';

    IconData actionIcon = Icons.report_problem;

    Color actionBtnColor = Colors.red.shade600;



    if (equipmentStatus == 'ชำรุด') {

      actionLabel = 'เริ่มงานซ่อม';

      actionIcon = Icons.build_circle;

      actionBtnColor = Colors.orange.shade700;

    } else if (equipmentStatus == 'อยู่ระหว่างซ่อม') {

      actionLabel = 'บันทึกผลการซ่อม';

      actionIcon = Icons.task_alt;

      actionBtnColor = Colors.green.shade600;

    } else if (equipmentStatus == 'ซ่อมไม่ได้') {

       actionLabel = 'ซ่อมอีกครั้ง';

       actionIcon = Icons.build_circle;

       actionBtnColor = Colors.orange.shade700;

    }



    return Container(

      margin: const EdgeInsets.symmetric(vertical: 10),

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(24), // More rounded

        boxShadow: [

          BoxShadow(

            color: statusColor.withValues(alpha: 0.1),

            blurRadius: 20,

            offset: const Offset(0, 8),

          ),

        ],

        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),

      ),

      child: Column(

        children: [

          // Status Header

          Row(

            children: [

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                decoration: BoxDecoration(

                  color: statusColor.withValues(alpha: 0.1),

                  borderRadius: BorderRadius.circular(20),

                ),

                child: Row(

                  children: [

                     Icon(Icons.info, size: 16, color: statusColor),

                     const SizedBox(width: 6),

                     Text(

                       'สถานะปัจจุบัน',

                       style: TextStyle(

                         fontSize: 12, 

                         fontWeight: FontWeight.bold, 

                         color: statusColor

                       ),

                     ),

                  ],

                ),

              ),

              if (latestIsRepairAgain && equipmentStatus == 'อยู่ระหว่างซ่อม') ...[

                const SizedBox(width: 8),

                Container(

                  padding:

                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                  decoration: BoxDecoration(

                    color: Colors.orange.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(

                      color: Colors.orange.withValues(alpha: 0.35),

                      width: 1,

                    ),

                  ),

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Icon(

                        Icons.restart_alt,

                        size: 14,

                        color: Colors.orange.shade800,

                      ),

                      const SizedBox(width: 6),

                      Text(

                        'ซ่อมอีกครั้ง',

                        style: TextStyle(

                          fontSize: 11,

                          fontWeight: FontWeight.bold,

                          color: Colors.orange.shade800,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

              const Spacer(),

            ],

          ),

          



          const SizedBox(height: 15),

          

          // Big Status Text

          Row(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              Icon(

                originalStatus == 'ปกติ' ? Icons.check_circle :

                originalStatus == 'ชำรุด' ? Icons.error :

                originalStatus == 'อยู่ระหว่างซ่อม' ? Icons.handyman : Icons.cancel,

                size: 36,

                color: statusColor,

              ),

              const SizedBox(width: 15),

              Text(

                originalStatus,

                style: TextStyle(

                  fontSize: 28,

                  fontWeight: FontWeight.w800,

                  color: statusColor,

                  letterSpacing: 0.5,

                ),

              ),

            ],

          ),



          // Show Repairer Name if Repairing (moved to bottom)

          if (equipmentStatus == 'อยู่ระหว่างซ่อม') ...[

             const SizedBox(height: 8),

             Container(

                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),

                decoration: BoxDecoration(

                  color: Colors.orange.withValues(alpha: 0.05),

                  borderRadius: BorderRadius.circular(12),

                ),

                child: Text(

                  'กำลังซ่อมโดย: ${ApiService().getUserName(latestWorkerName ?? inspectorName)}',

                  style: TextStyle(

                    fontSize: 14, 

                    fontWeight: FontWeight.w500, 

                    color: Colors.orange.shade800

                  ),

                  textAlign: TextAlign.center,

                ),

             ),

          ],

          

          const SizedBox(height: 25),



          // Action Button (Only for Admin)

          // Action Button (Only for Admin)

          if (isAdmin)

             Builder(

               builder: (context) {

                 // Check Lock

                 bool isLocked = false;

                 

                 // 1. Check by ID (Primary)

                 if (equipmentStatus == 'อยู่ระหว่างซ่อม' && 

                     repairerId != null && 

                     repairerId != currentUid) {

                   isLocked = true;

                 }

                 // 2. Check by Name (Fallback for legacy data)

                 else if (equipmentStatus == 'อยู่ระหว่างซ่อม' &&

                     repairerId == null &&

                     (latestWorkerName != null || inspectorName != null)) {

                    final currentName = ApiService().currentUser?['fullname'];

                    final byName = (latestWorkerName != null && latestWorkerName!.trim().isNotEmpty)

                        ? latestWorkerName!.trim()

                        : (inspectorName ?? '').trim();

                    if (byName.isNotEmpty && byName != (currentName ?? '')) {

                       isLocked = true;

                    }

                 }



                 return SizedBox(

                    width: double.infinity,

                    height: 56,

                    child: ElevatedButton.icon(

                      onPressed: isLocked

                          ? null

                          : (equipmentStatus == 'ซ่อมไม่ได้'

                              ? _showRepairAgainDialog

                              : _showStatusDialog),

                      style: ElevatedButton.styleFrom(

                        backgroundColor: isLocked ? Colors.grey : actionBtnColor,

                        foregroundColor: Colors.white,

                        elevation: isLocked ? 0 : 4,

                        shadowColor: actionBtnColor.withValues(alpha: 0.4),

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(16),

                        ),

                      ),

                      icon: Icon(isLocked ? Icons.lock : actionIcon, size: 24),

                      label: Text(

                        isLocked ? 'อยู่ระหว่างดำเนินการโดยผู้อื่น' : actionLabel,

                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

                      ),

                    ),

                  );

               }

             ),

          

          if (!isAdmin)

             SizedBox(

               width: double.infinity,

               height: 56,

               child: ElevatedButton.icon(

                 onPressed: _showReportProblemDialog,

                 style: ElevatedButton.styleFrom(

                   backgroundColor: Colors.red.shade600,

                   foregroundColor: Colors.white,

                   elevation: 4,

                   shadowColor: Colors.red.withValues(alpha: 0.35),

                   shape: RoundedRectangleBorder(

                     borderRadius: BorderRadius.circular(16),

                   ),

                 ),

                 icon: const Icon(Icons.report_problem, size: 24),

                 label: const Text(

                   'แจ้งปัญหา',

                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

                 ),

               ),

             ),

        ],

      ),

    );

  }



  // Section ผู้ตรวจสอบล่าสุด (แสดงเฉพาะตอนสถานะปกติ)

  Widget _buildInspectorSection() {

    // ถ้ายังไม่มีผู้ตรวจสอบ ให้ซ่อนไปเลย

    if ((equipmentStatus == 'ปกติ' &&

            (lastNormalInspectorName == null ||

                lastNormalInspectorName!.trim().isEmpty)) &&

        (inspectorName == null || inspectorName!.isEmpty)) {

      return const SizedBox.shrink();

    }



    // ⭐ If current status is Normal, always show "Inspector" (blue) based on latest normal audit

    final bool showNormalInspector = equipmentStatus == 'ปกติ';



    // ⭐ Determine if this was a Repair or regular Audit

    bool isRepaired = !showNormalInspector && lastAuditStatus == 3;

    String title = isRepaired ? 'ผู้ซ่อมบำรุงล่าสุด' : 'ผู้ตรวจสอบล่าสุด';

    IconData headerIcon = isRepaired ? Icons.handyman : Icons.check_circle;

    Color themeColor = isRepaired ? Colors.orange : const Color(0xFF5593E4);



    String _formatFinishedAt(DateTime? dt) {

      if (dt == null) return '-';

      final day = dt.day.toString().padLeft(2, '0');

      final month = dt.month.toString().padLeft(2, '0');

      final year = (dt.year + 543).toString();

      final hour = dt.hour.toString().padLeft(2, '0');

      final minute = dt.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';

    }



    final String displayName = showNormalInspector

        ? (lastNormalInspectorName ?? inspectorName ?? 'ยังไม่มีการตรวจสอบ')

        : (inspectorName ?? 'ยังไม่มีการตรวจสอบ');



    final String? displayNote = showNormalInspector

        ? (lastNormalAuditNote ?? '')

        : (lastAuditNote ?? '');



    final String? displayImage = showNormalInspector

        ? (lastNormalEvidenceImage ?? '')

        : '';



    final bool shouldShowFinishedResult =

        (latestFinishedRemark != null && latestFinishedRemark!.trim().isNotEmpty) ||

        (latestFinishedImageUrl != null && latestFinishedImageUrl!.trim().isNotEmpty);



    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(

          color: themeColor.withOpacity(0.25),

          width: 2,

        ),

        boxShadow: [

          BoxShadow(

            color: themeColor.withOpacity(0.08),

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

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(

                  color: themeColor.withOpacity(0.1),

                  borderRadius: BorderRadius.circular(12),

                ),

                child: Icon(

                  headerIcon,

                  color: themeColor,

                  size: 24,

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: TextStyle(

                        fontSize: 18,

                        fontWeight: FontWeight.bold,

                        color: Colors.grey.shade800,

                      ),

                    ),

                    Text(

                      isRepaired ? 'บันทึกงานซ่อมเสร็จสิ้น' : 'ตรวจสอบความเรียบร้อย',

                      style: TextStyle(

                        fontSize: 11,

                        color: Colors.grey.shade500,

                        letterSpacing: 0.5,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 15),



          // ผู้ตรวจสอบ - Box

          Container(

            width: double.infinity,

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

            decoration: BoxDecoration(

              color: themeColor.withOpacity(0.08),

              borderRadius: BorderRadius.circular(14),

              border: Border.all(

                color: themeColor.withOpacity(0.2),

                width: 1.5,

              ),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity(0.03),

                  blurRadius: 5,

                  offset: const Offset(0, 2),

                ),

              ],

            ),

            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(

                    color: themeColor.withOpacity(0.1),

                    borderRadius: BorderRadius.circular(8),

                  ),

                  child: Icon(

                    Icons.person,

                    color: themeColor,

                    size: 20,

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Text(

                    displayName,

                    style: TextStyle(

                      fontSize: 15,

                      color: const Color(0xFF1E5AA8),

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ),

              ],

            ),

          ),



          // ⭐ Optional Note Section (Only if not empty)

          if (displayNote != null && displayNote!.trim().isNotEmpty) ...[

            const SizedBox(height: 12),

            Container(

              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                color: themeColor.withOpacity(0.06),

                borderRadius: BorderRadius.circular(14),

                border: Border.all(color: themeColor.withOpacity(0.2)),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      Icon(Icons.sticky_note_2_outlined, color: themeColor, size: 16),

                      const SizedBox(width: 8),

                      Text(

                        'หมายเหตุงานซ่อม',

                        style: TextStyle(

                          fontSize: 13,

                          fontWeight: FontWeight.bold,

                          color: themeColor,

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 6),

                  Text(

                    displayNote!,

                    style: TextStyle(

                      fontSize: 14,

                      color: Colors.grey.shade800,

                      height: 1.4,

                    ),

                  ),

                ],

              ),

            ),

          ],



          if (displayImage != null && displayImage.trim().isNotEmpty) ...[

            const SizedBox(height: 12),

            GestureDetector(

              onTap: () => _showFullScreenImage(context, displayImage.trim()),

              child: Container(

                height: 200,

                width: double.infinity,

                decoration: BoxDecoration(

                  color: themeColor.withOpacity(0.03),

                  borderRadius: BorderRadius.circular(16),

                  border: Border.all(color: themeColor.withOpacity(0.25)),

                ),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(16),

                  child: Image.network(

                    displayImage.trim(),

                    fit: BoxFit.contain,

                    errorBuilder: (ctx, err, stack) => const Center(

                      child: Text('โหลดรูปภาพไม่สำเร็จ'),

                    ),

                  ),

                ),

              ),

            ),

          ],



          if (shouldShowFinishedResult) ...[

            const SizedBox(height: 12),

            Container(

              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                color: const Color(0xFF5593E4).withValues(alpha: 0.08),

                borderRadius: BorderRadius.circular(14),

                border: Border.all(color: const Color(0xFF5593E4).withValues(alpha: 0.35)),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      const Icon(Icons.check_circle, color: Color(0xFF5593E4), size: 16),

                      const SizedBox(width: 8),

                      Text(

                        'ผลปิดงานซ่อม',

                        style: TextStyle(

                          fontSize: 13,

                          fontWeight: FontWeight.bold,

                          color: const Color(0xFF1E5AA8),

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 6),

                  RichText(

                    text: TextSpan(

                      style: const TextStyle(fontSize: 13),

                      children: [

                        const TextSpan(

                          text: 'ตรวจสอบเสร็จแล้ว: ',

                          style: TextStyle(color: Color(0xFF1E5AA8)),

                        ),

                        TextSpan(

                          text: _formatFinishedAt(latestFinishedAt),

                          style: const TextStyle(color: Colors.black87),

                        ),

                      ],

                    ),

                  ),

                  if (latestFinishedByName != null && latestFinishedByName!.trim().isNotEmpty) ...[

                    const SizedBox(height: 4),

                    RichText(

                      text: TextSpan(

                        style: const TextStyle(fontSize: 13),

                        children: [

                          const TextSpan(

                            text: 'ผู้ปิดงาน: ',

                            style: TextStyle(color: Color(0xFF1E5AA8)),

                          ),

                          TextSpan(

                            text: latestFinishedByName!.trim(),

                            style: const TextStyle(color: Colors.black87),

                          ),

                        ],

                      ),

                    ),

                  ],

                  if (latestFinishedRemark != null && latestFinishedRemark!.trim().isNotEmpty) ...[

                    const SizedBox(height: 4),

                    RichText(

                      text: TextSpan(

                        style: const TextStyle(fontSize: 13, height: 1.35),

                        children: [

                          const TextSpan(

                            text: 'หมายเหตุ: ',

                            style: TextStyle(color: Color(0xFF1E5AA8)),

                          ),

                          TextSpan(

                            text: latestFinishedRemark!.trim(),

                            style: const TextStyle(color: Colors.black87),

                          ),

                        ],

                      ),

                    ),

                  ],

                  if (latestFinishedImageUrl != null && latestFinishedImageUrl!.trim().isNotEmpty) ...[

                    const SizedBox(height: 12),

                    GestureDetector(

                      onTap: () => _showFullScreenImage(context, latestFinishedImageUrl!.trim()),

                      child: Container(

                        height: 200,

                        width: double.infinity,

                        decoration: BoxDecoration(

                          color: Colors.transparent,

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(

                            color: const Color(0xFF5593E4).withValues(alpha: 0.35),

                          ),

                        ),

                        child: ClipRRect(

                          borderRadius: BorderRadius.circular(16),

                          child: Image.network(

                            latestFinishedImageUrl!.trim(),

                            fit: BoxFit.contain,

                            errorBuilder: (ctx, err, stack) => const Center(

                              child: Text('โหลดรูปภาพไม่สำเร็จ'),

                            ),

                          ),

                        ),

                      ),

                    ),

                  ],

                ],

              ),

            ),

          ],

        ],

      ),

    );

  }



  // Section ผู้สร้าง (แสดงตลอด)

  Widget _buildCreatorSection() {

    // Determine the name to display

    String? displayCreator = creatorName;

    

    // Fallback to widget data if state is null

    displayCreator ??= widget.equipment['created_name']?.toString();

    

    // Fallback to current user ONLY if we still don't have a name

    if (displayCreator == null || displayCreator.isEmpty || displayCreator == 'ไม่ระบุ') {

       displayCreator = ApiService().currentUser?['name'] ?? 'ไม่ระบุ';

    }



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

          // Header

          Row(

            children: [

              Container(

                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(

                  color: const Color(0xFF10B981).withValues(alpha: 0.1), // Green tint

                  borderRadius: BorderRadius.circular(10),

                ),

                child: const Icon(

                  Icons.verified_user,

                  color: Color(0xFF10B981),

                  size: 24,

                ),

              ),

              const SizedBox(width: 12),

              Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    'ผู้เพิ่มครุภัณฑ์',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                      color: Colors.grey.shade800,

                    ),

                  ),

                  Text(

                    'ผู้บันทึกข้อมูล',

                    style: TextStyle(

                      fontSize: 12,

                      color: Colors.grey.shade500,

                    ),

                  ),

                ],

              ),

            ],

          ),

          const SizedBox(height: 20),



          // Content Box

          Container(

            width: double.infinity,

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

            decoration: BoxDecoration(

              color: const Color(0xFF10B981).withValues(alpha: 0.05),

              borderRadius: BorderRadius.circular(16),

              border: Border.all(

                color: const Color(0xFF10B981).withValues(alpha: 0.2),

              ),

            ),

            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(

                    color: Colors.white,

                    borderRadius: BorderRadius.circular(10),

                  ),

                  child: const Icon(

                    Icons.person,

                    color: Color(0xFF059669),

                    size: 20,

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                       Text(

                        'ชื่อผู้เพิ่ม',

                        style: TextStyle(

                          fontSize: 11,

                          color: Colors.green.shade700,

                        ),

                      ),

                      Text(

                        displayCreator ?? 'ไม่ระบุ',

                        style: const TextStyle(

                          fontSize: 15,

                          color: Color(0xFF059669),

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }







  // Section ผู้แจ้ง

  Widget _buildReporterSection() {

    final bool isRepairAgain = latestIsRepairAgain;

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

                    isRepairAgain ? 'ซ่อมอีกครั้ง' : 'การแจ้งปัญหา',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                      color: Colors.grey.shade800,

                    ),

                  ),

                  Text(

                    isRepairAgain ? 'เปิดรอบซ่อมใหม่' : 'รายงานข้อขัดข้อง',

                    style: const TextStyle(fontSize: 12, color: Colors.grey),

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

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        isRepairAgain ? 'ผู้เปิดงาน' : 'ผู้แจ้ง',

                        style: TextStyle(

                          fontSize: 12,

                          color: Colors.red.shade300,

                        ),

                      ),

                      Text(

                        ApiService().getUserName(reporterName),

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(

                          fontSize: 15,

                          fontWeight: FontWeight.bold,

                          color: Colors.red.shade900,

                          fontStyle: (reporterName != null)

                              ? FontStyle.normal

                              : FontStyle.italic,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),



          // เหตุผล (Report Reason)

          // Show only when there's actual report reason

          if (reportReason != null && reportReason!.trim().isNotEmpty) ...[

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

                    reportReason!,

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

                                    ? InteractiveViewer(

                                        child: Image.network(

                                          imgPath,

                                          fit: BoxFit.contain,

                                        ),

                                      )

                                    : InteractiveViewer(

                                        child: Image.file(

                                          File(imgPath),

                                          fit: BoxFit.contain,

                                        ),

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



  // Fullscreen Image Preview

  void _showFullScreenImage(BuildContext context, String imageUrl) {

    showDialog(

      context: context,

      builder: (context) => Dialog(

        backgroundColor: Colors.transparent,

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

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                QrImageView(

                  data: qrData,

                  version: QrVersions.auto,

                  size: 200.0,

                  backgroundColor: Colors.white,

                  eyeStyle: const QrEyeStyle(

                    eyeShape: QrEyeShape.square,

                    color: Color(0xFF9A2C2C),

                  ),

                ),

                const SizedBox(height: 12),

                Row(

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

