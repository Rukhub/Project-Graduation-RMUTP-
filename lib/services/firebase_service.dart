import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/asset_model.dart';
import '../models/location_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getPermanentAssetsStream({
    bool activeOnly = true,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('assets_permanent');
    return q.snapshots().map((snapshot) {
      final items = snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        data['permanent_id'] ??= d.id;
        return data;
      }).toList();
      items.sort((a, b) {
        final ap = a['permanent_id']?.toString() ?? '';
        final bp = b['permanent_id']?.toString() ?? '';
        return ap.compareTo(bp);
      });
      return items;
    });
  }

  Future<int> getPermanentStatus(String permanentId) async {
    try {
      final id = permanentId.toString().trim();
      if (id.isEmpty) return 2;
      final doc = await _db.collection('assets_permanent').doc(id).get();
      if (!doc.exists) return 2;
      final data = doc.data() ?? {};
      final rawStatus = data['permanent_status'];
      final status = rawStatus is int
          ? rawStatus
          : int.tryParse(rawStatus?.toString() ?? '') ?? 2;
      return status;
    } catch (e) {
      debugPrint('getPermanentStatus error: $e');
      return 2;
    }
  }

  String _assetIdRootForSuffix(String assetId) {
    final trimmed = assetId.toString().trim();
    final m = RegExp(r'^(.*)_(\d+)$').firstMatch(trimmed);
    if (m == null) return trimmed;
    return m.group(1) ?? trimmed;
  }

  int? _assetIdSuffixNumber(String assetId, String root) {
    final trimmed = assetId.toString().trim();
    if (trimmed == root) return 1;
    if (!trimmed.startsWith('${root}_')) return null;
    final suffix = trimmed.substring(root.length + 1);
    return int.tryParse(suffix);
  }

  Future<String?> generateNextAvailableAssetId(String requestedAssetId) async {
    try {
      final root = _assetIdRootForSuffix(requestedAssetId);
      if (root.trim().isEmpty) return null;

      // If the requested root itself is available, prefer it.
      final rootAvailable = await isAssetIdAvailable(root);
      if (rootAvailable) return root;

      // Query existing asset_ids with prefix root (root or root-<n>).
      final start = root;
      final end = '$root\uf8ff';
      final snapshot = await _db
          .collection('assets')
          .where('asset_id', isGreaterThanOrEqualTo: start)
          .where('asset_id', isLessThan: end)
          .limit(200)
          .get();

      int maxSuffix = 1; // root exists => first duplicate should become _2
      for (final d in snapshot.docs) {
        final id = d.data()['asset_id']?.toString() ?? d.id;
        final n = _assetIdSuffixNumber(id, root);
        if (n != null && n > maxSuffix) {
          maxSuffix = n;
        }
      }

      // Next id = root_(max+1)
      final candidate = '${root}_${maxSuffix + 1}';
      final candidateAvailable = await isAssetIdAvailable(candidate);
      if (candidateAvailable) return candidate;

      // Fallback linear probe (rare)
      for (int i = maxSuffix + 2; i < maxSuffix + 50; i++) {
        final c = '${root}_$i';
        final ok = await isAssetIdAvailable(c);
        if (ok) return c;
      }

      return null;
    } catch (e) {
      debugPrint('generateNextAvailableAssetId error: $e');
      return null;
    }
  }

  Future<String?> validatePermanentIdForNewAsset(String permanentId) async {
    try {
      final id = permanentId.toString().trim();
      if (id.isEmpty) return 'กรุณาเลือกกลุ่มสินทรัพย์ถาวร';

      final doc = await _db.collection('assets_permanent').doc(id).get();
      if (!doc.exists) return 'ไม่พบกลุ่มสินทรัพย์ถาวรนี้ในระบบ';

      final data = doc.data() ?? {};
      final rawStatus = data['permanent_status'];
      final status = rawStatus is int
          ? rawStatus
          : int.tryParse(rawStatus?.toString() ?? '') ?? 2;

      if (status == 1) {
        QuerySnapshot<Map<String, dynamic>> used = await _db
            .collection('assets')
            .where('permanent_id', isEqualTo: id)
            .limit(1)
            .get();

        // Fallback for old/mistyped field in existing data
        if (used.docs.isEmpty) {
          used = await _db
              .collection('assets')
              .where('permenant_id', isEqualTo: id)
              .limit(1)
              .get();
        }

        if (used.docs.isNotEmpty) {
          final usedData = used.docs.first.data();
          final usedAssetId = (usedData['asset_id'] ?? used.docs.first.id)
              ?.toString();
          final usedName = (usedData['asset_name'] ?? usedData['name_asset'])
              ?.toString();

          final idText = (usedAssetId != null && usedAssetId.trim().isNotEmpty)
              ? usedAssetId.trim()
              : null;
          final nameText = (usedName != null && usedName.trim().isNotEmpty)
              ? usedName.trim()
              : null;

          if (idText != null && nameText != null) {
            return 'กลุ่มสินทรัพย์ถาวรนี้ห้ามซ้ำ (ครุภัณฑ์: $idText / ชื่อ: $nameText)';
          }
          if (idText != null) {
            return 'กลุ่มสินทรัพย์ถาวรนี้ห้ามซ้ำ (ซ้ำกับครุภัณฑ์: $idText)';
          }
          if (nameText != null) {
            return 'กลุ่มสินทรัพย์ถาวรนี้ห้ามซ้ำ (ซ้ำกับ: $nameText)';
          }
          return 'กลุ่มสินทรัพย์ถาวรนี้ห้ามซ้ำ';
        }
      }

      return null;
    } catch (e) {
      debugPrint('validatePermanentIdForNewAsset error: $e');
      return 'ตรวจสอบกลุ่มสินทรัพย์ถาวรไม่สำเร็จ';
    }
  }

  Future<Map<String, dynamic>?> getPermanentAssetById(
    String permanentId,
  ) async {
    try {
      final id = permanentId.toString().trim();
      if (id.isEmpty) return null;
      final doc = await _db.collection('assets_permanent').doc(id).get();
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data() ?? {});
      data['id'] = doc.id;
      data['permanent_id'] ??= doc.id;
      return data;
    } catch (e) {
      debugPrint('getPermanentAssetById error: $e');
      return null;
    }
  }

  Future<bool> addPermanentAssetGroup({required String permanentId}) async {
    try {
      final id = permanentId.toString().trim();
      if (id.isEmpty) return false;

      final ref = _db.collection('assets_permanent').doc(id);
      final existing = await ref.get();
      if (existing.exists) return false;

      await ref.set({
        'permanent_id': id,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('addPermanentAssetGroup error: $e');
      return false;
    }
  }

  Future<int> purgeIsActiveFieldFromPermanentAssets() async {
    try {
      int updated = 0;

      DocumentSnapshot<Map<String, dynamic>>? lastDoc;
      while (true) {
        Query<Map<String, dynamic>> q = _db
            .collection('assets_permanent')
            .orderBy(FieldPath.documentId)
            .limit(500);
        if (lastDoc != null) {
          q = q.startAfterDocument(lastDoc!);
        }

        final snapshot = await q.get();
        if (snapshot.docs.isEmpty) break;

        int updatedInBatch = 0;
        final batch = _db.batch();
        for (final d in snapshot.docs) {
          final data = d.data();
          if (data.containsKey('is_active')) {
            batch.update(d.reference, {'is_active': FieldValue.delete()});
            updatedInBatch += 1;
          }
        }

        if (updatedInBatch > 0) {
          await batch.commit();
          updated += updatedInBatch;
        }

        lastDoc = snapshot.docs.last;

        if (snapshot.docs.length < 500) break;
      }

      return updated;
    } catch (e) {
      debugPrint('purgeIsActiveFieldFromPermanentAssets error: $e');
      return 0;
    }
  }

  Future<int> countAssetsByPermanentId(String permanentId) async {
    try {
      final id = permanentId.toString().trim();
      if (id.isEmpty) return 0;
      final snapshot = await _db
          .collection('assets')
          .where('permanent_id', isEqualTo: id)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('countAssetsByPermanentId error: $e');
      return 0;
    }
  }

  Future<bool> canSetPermanentStatusUnique(String permanentId) async {
    final count = await countAssetsByPermanentId(permanentId);
    return count <= 1;
  }

  Future<bool> deletePermanentAssetGroup(String permanentId) async {
    try {
      final id = permanentId.toString().trim();
      if (id.isEmpty) return false;

      final ref = _db.collection('assets_permanent').doc(id);
      final doc = await ref.get();
      if (!doc.exists) return false;

      final assetCount = await countAssetsByPermanentId(id);
      if (assetCount > 0) {
        return false;
      }

      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('deletePermanentAssetGroup error: $e');
      return false;
    }
  }

  Future<bool> updatePermanentAssetGroup(
    String permanentId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final id = permanentId.toString().trim();
      if (id.isEmpty) return false;

      // Safety: If trying to set unique(1), ensure at most 1 asset is linked.
      if (fields.containsKey('permanent_status')) {
        final raw = fields['permanent_status'];
        final status = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
        if (status == 1) {
          final ok = await canSetPermanentStatusUnique(id);
          if (!ok) return false;
        }
      }

      await _db.collection('assets_permanent').doc(id).update(fields);
      return true;
    } catch (e) {
      debugPrint('updatePermanentAssetGroup error: $e');
      return false;
    }
  }

  static int reportStatusToCode(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty || s == 'null') return 1;
    if (s == 'pending') return 1;
    if (s == 'repairing') return 2;
    if (s == 'completed') return 3;
    if (s == 'cancelled') return 4;
    final asInt = int.tryParse(s);
    return asInt ?? 1;
  }

  Future<Map<String, dynamic>?> getLatestOpenReportForAsset(
    String assetId,
  ) async {
    try {
      final id = assetId.trim();
      if (id.isEmpty) return null;

      final snapshot = await _db
          .collection('reports_history')
          .where('asset_id', isEqualTo: id)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final openDocs = snapshot.docs.where((d) {
        final data = d.data();
        final s = reportStatusToCode(data['report_status']);
        return s == 1 || s == 2;
      }).toList();

      if (openDocs.isEmpty) return null;

      openDocs.sort((a, b) {
        final ad = a.data();
        final bd = b.data();
        final at = ad['reported_at'] ?? ad['timestamp'];
        final bt = bd['reported_at'] ?? bd['timestamp'];

        DateTime aDt;
        if (at is Timestamp) {
          aDt = at.toDate();
        } else if (at is DateTime) {
          aDt = at;
        } else {
          aDt = DateTime.fromMillisecondsSinceEpoch(0);
        }

        DateTime bDt;
        if (bt is Timestamp) {
          bDt = bt.toDate();
        } else if (bt is DateTime) {
          bDt = bt;
        } else {
          bDt = DateTime.fromMillisecondsSinceEpoch(0);
        }

        final c = bDt.compareTo(aDt);
        if (c != 0) return c;
        return b.id.compareTo(a.id);
      });

      final latest = openDocs.first;
      final out = Map<String, dynamic>.from(latest.data());
      out['id'] = latest.id;
      return out;
    } catch (e) {
      debugPrint('getLatestOpenReportForAsset error: $e');
      return null;
    }
  }

  Future<bool> hasOpenReportForAsset(String assetId) async {
    try {
      final id = assetId.trim();
      if (id.isEmpty) return false;

      // Avoid composite-index requirement: only filter by asset_id and then
      // filter statuses in memory.
      final snapshot = await _db
          .collection('reports_history')
          .where('asset_id', isEqualTo: id)
          .get();

      if (snapshot.docs.isEmpty) return false;
      for (final d in snapshot.docs) {
        final data = d.data();
        final s = reportStatusToCode(data['report_status']);
        if (s == 1 || s == 2) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('hasOpenReportForAsset error: $e');
      return false;
    }
  }

  static String reportStatusLabel(dynamic value) {
    final c = reportStatusToCode(value);
    if (c == 2) return 'กำลังซ่อม';
    if (c == 3) return 'ซ่อมเสร็จ';
    if (c == 4) return 'ยกเลิก/ซ่อมไม่ได้';
    return 'รอดำเนินการ';
  }

  Map<String, dynamic> _normalizeAssetWriteData(Map<String, dynamic> input) {
    return Map<String, dynamic>.from(input);
  }

  Map<String, dynamic> _normalizeCheckLogWriteData(Map<String, dynamic> input) {
    return Map<String, dynamic>.from(input);
  }

  Map<String, dynamic> _normalizeReportWriteData(Map<String, dynamic> input) {
    final out = Map<String, dynamic>.from(input);

    // Schema normalization: remark_report -> report_remark
    if (!out.containsKey('report_remark') && out.containsKey('remark_report')) {
      out['report_remark'] = out['remark_report'];
    }
    out.remove('remark_report');

    // Schema normalization: remark_finished -> finished_remark
    if (!out.containsKey('finished_remark') &&
        out.containsKey('remark_finished')) {
      out['finished_remark'] = out['remark_finished'];
    }
    out.remove('remark_finished');

    return out;
  }

  Map<String, dynamic> _normalizeAuditWriteData(Map<String, dynamic> input) {
    return Map<String, dynamic>.from(input);
  }

  static const Set<String> _purgeAllowedCollections = {
    'reports_history',
    'audits_history',
    'check_logs',
    'assets',
  };

  Future<int> deleteDocsFromCollection({
    required String collection,
    required int count,
  }) async {
    final target = collection.trim();
    if (!_purgeAllowedCollections.contains(target)) {
      throw Exception('Collection not allowed');
    }
    if (count <= 0) return 0;

    int deleted = 0;
    while (deleted < count) {
      final int remaining = count - deleted;
      final int batchSize = remaining > 500 ? 500 : remaining;

      final snapshot = await _db.collection(target).limit(batchSize).get();

      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snapshot.docs.length;

      if (snapshot.docs.length < batchSize) break;
    }

    return deleted;
  }

  Future<int> deleteReportsHistoryDocs({required int count}) async {
    return deleteDocsFromCollection(
      collection: 'reports_history',
      count: count,
    );
  }

  // --- User Profile ---
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Firebase getUserProfile Error: $e');
      return null;
    }
  }

  Future<bool> updateUserProfileFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    try {
      final id = uid.trim();
      if (id.isEmpty) return false;

      await _db.collection('users').doc(id).update({...fields});
      return true;
    } catch (e) {
      debugPrint('Update user error: $e');
      return false;
    }
  }

  Future<void> updateLatestReportForAsset(
    String assetId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final normalizedUpdate = _normalizeReportWriteData(updateData);
      // Avoid composite-index requirement by not combining where(...) with orderBy(...).
      final snapshot = await _db
          .collection('reports_history')
          .where('asset_id', isEqualTo: assetId)
          .get();

      if (snapshot.docs.isEmpty) return;

      // Our reports_history docId includes a sortable timestamp suffix.
      final docs = snapshot.docs.toList();
      docs.sort((a, b) => b.id.compareTo(a.id));

      await docs.first.reference.update(normalizedUpdate);
    } catch (e) {
      debugPrint('🚨 updateLatestReportForAsset Error: $e');
    }
  }

  Future<UserModel?> getUserProfileByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Firebase getUserProfileByUid Error: $e');
      return null;
    }
  }

  /// Synchronize user with Firestore after Google Login
  Future<UserModel> syncUserWithFirestore(dynamic firebaseUser) async {
    final uid = firebaseUser.uid;
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // Update existing user (optional: update photo or name if changed)
      final existingData = doc.data()!;
      final user = UserModel.fromFirestore(existingData, uid);
      return user;
    } else {
      // Create new user with default role 0 and is_approved false
      final newUser = UserModel(
        uid: uid,
        email: firebaseUser.email ?? '',
        fullname: firebaseUser.displayName ?? 'Unknown User',
        photoUrl: firebaseUser.photoURL,
        role: 0, // Default to Normal User
        isApproved: false, // Must wait for Admin approval
      );
      await docRef.set(newUser.toFirestore());
      return newUser;
    }
  }

  Future<String?> uploadRepairImage(File imageFile, String assetId) async {
    try {
      String fileName =
          'repair_${assetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('repair_evidence')
          .child(fileName);

      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading repair image: $e');
      return null;
    }
  }

  // --- Assets ---
  Stream<List<AssetModel>> getAssetsStream() {
    return _db.collection('assets').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AssetModel.fromFirestore(doc.data()))
          .toList();
    });
  }

  Stream<List<AssetModel>> getAssetsByLocationStream(dynamic locationId) {
    return _db
        .collection('assets')
        .where('location_id', isEqualTo: locationId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AssetModel.fromFirestore(doc.data()))
              .toList();
        });
  }

  Future<List<AssetModel>> getAssets() async {
    final snapshot = await _db.collection('assets').get();
    return snapshot.docs
        .map((doc) => AssetModel.fromFirestore(doc.data()))
        .toList();
  }

  // --- Locations (Rooms) ---
  Future<List<LocationModel>> getLocations() async {
    final snapshot = await _db.collection('locations').get();
    return snapshot.docs
        .map((doc) => LocationModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<LocationModel?> getLocationById(dynamic locationId) async {
    if (locationId == null) return null;
    try {
      final doc = await _db
          .collection('locations')
          .doc(locationId.toString())
          .get();
      if (doc.exists) {
        return LocationModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- CRUD Operations ---

  Future<void> updateAsset(String assetId, Map<String, dynamic> data) async {
    final trimmed = assetId.toString().trim();
    if (trimmed.isEmpty) return;

    final normalized = _normalizeAssetWriteData(data);

    // 1. Try updating by sanitized Doc ID directly
    try {
      final safeId = _sanitizeDocId(trimmed);
      await _db.collection('assets').doc(safeId).update(normalized);
      return; // Success, exit
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') {
        debugPrint('⚠️ Direct update failed: $e');
        // Continue to fallback if strictly not-found?
        // Or if invalid-arg?
        // If it was just not found, we continue.
      }
      // If it failed for other reasons, we might still want to try fallback?
    } catch (e) {
      // Catch PlatformException for invalid Ref if _sanitizeDocId missed something?
      debugPrint('⚠️ Direct update error: $e');
    }

    // 2. Fallback: Query by field 'asset_id'
    final snapshot = await _db
        .collection('assets')
        .where('asset_id', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update(normalized);
      return;
    }

    // 3. Fallback: Query by 'asset_id' with / replaced by - (legacy?)
    // Or just fail.

    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'not-found',
      message: 'Asset not found for asset_id=$trimmed',
    );
  }

  Future<void> moveAssetsToLocation({
    required Iterable<String> assetIds,
    required dynamic targetLocationId,
    String? targetLocationName,
  }) async {
    final ids = assetIds
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    const int batchLimit = 450;
    for (int i = 0; i < ids.length; i += batchLimit) {
      final chunk = ids.skip(i).take(batchLimit);
      final batch = _db.batch();

      for (final assetId in chunk) {
        // Sanitize: replace / with _ to match Firestore doc ID format
        final safeId = _sanitizeDocId(assetId);
        final ref = _db.collection('assets').doc(safeId);
        final updateData = <String, dynamic>{'location_id': targetLocationId};
        if (targetLocationName != null) {
          updateData['location_name'] = targetLocationName;
        }
        batch.update(ref, updateData);
      }

      await batch.commit();
    }
  }

  Future<void> deleteAsset(String assetId) async {
    final trimmed = assetId.toString().trim();
    if (trimmed.isEmpty) return;

    // Sanitize the ID — asset_ids may contain "/" which is invalid in doc paths
    final sanitized = _sanitizeDocId(trimmed);
    final ref = _db.collection('assets').doc(sanitized);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return;
    }

    // Fallback: query by asset_id field (handles any doc ID mismatch)
    final snapshot = await _db
        .collection('assets')
        .where('asset_id', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
      return;
    }

    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'not-found',
      message: 'Asset not found for asset_id=$trimmed',
    );
  }

  // --- Check Logs ---
  Future<void> createCheckLog(Map<String, dynamic> log) async {
    final normalized = _normalizeCheckLogWriteData(log);
    await _db.collection('check_logs').add({
      ...normalized,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _sanitizeDocIdPart(String value) {
    return value
        .trim()
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('#', '_')
        .replaceAll('?', '_')
        .replaceAll('%', '_');
  }

  // Create Audit Log (New Strict Schema)
  Future<void> createAuditLog(Map<String, dynamic> auditData) async {
    auditData = _normalizeAuditWriteData(auditData);
    // Ensure audit_at is set
    if (!auditData.containsKey('audited_at')) {
      auditData['audited_at'] = FieldValue.serverTimestamp();
    }

    if (!auditData.containsKey('auditor_name') ||
        (auditData['auditor_name']?.toString().trim().isEmpty ?? true)) {
      try {
        final uid = auditData['auditor_id']?.toString();
        if (uid != null && uid.trim().isNotEmpty) {
          final userDoc = await _db.collection('users').doc(uid.trim()).get();
          final userData = userDoc.data();
          final fullname = userData?['fullname']?.toString();
          if (fullname != null && fullname.trim().isNotEmpty) {
            auditData['auditor_name'] = fullname.trim();
          }
        }
      } catch (e) {
        debugPrint('Error resolving auditor_name for audit log: $e');
      }
    }

    if (!auditData.containsKey('asset_name') ||
        (auditData['asset_name']?.toString().trim().isEmpty ?? true)) {
      try {
        final assetId = auditData['asset_id']?.toString();
        if (assetId != null && assetId.trim().isNotEmpty) {
          final trimmed = assetId.trim();

          Map<String, dynamic>? assetData;
          try {
            final doc = await _db.collection('assets').doc(trimmed).get();
            assetData = doc.data();
          } catch (_) {}

          assetData ??= () {
            return null;
          }();

          if (assetData == null) {
            final snapshot = await _db
                .collection('assets')
                .where('asset_id', isEqualTo: trimmed)
                .limit(1)
                .get();
            if (snapshot.docs.isNotEmpty) {
              assetData = snapshot.docs.first.data();
            }
          }

          final an = assetData?['asset_name']?.toString();
          if (an != null && an.trim().isNotEmpty) {
            auditData['asset_name'] = an.trim();
          }
        }
      } catch (e) {
        debugPrint('Error resolving asset_name for audit log: $e');
      }
    }

    final now = DateTime.now().toUtc();
    final String timestampStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}-"
        "${now.millisecond.toString().padLeft(3, '0')}";

    final assetId = _sanitizeDocIdPart(auditData['asset_id']?.toString() ?? '');
    final auditorId = _sanitizeDocIdPart(
      auditData['auditor_id']?.toString() ?? 'unknown',
    );
    final statusPart = _sanitizeDocIdPart(
      auditData['audit_status']?.toString() ?? '',
    );

    final auditorShort = auditorId.length <= 6
        ? auditorId
        : auditorId.substring(0, 6);
    final String customDocId =
        "${assetId.isEmpty ? 'unknown_asset' : assetId}_$timestampStr"
        "${statusPart.isEmpty ? '' : '_s$statusPart'}"
        "_${auditorShort.isEmpty ? 'unknown' : auditorShort}";

    await _db.collection('audits_history').doc(customDocId).set(auditData);
    debugPrint("Audit Log Created: ${auditData['asset_id']} ($customDocId)");
  }

  Future<int> migrateAuditsHistoryDocIds({
    bool deleteOld = false,
    int batchSize = 400,
  }) async {
    int migratedCount = 0;

    Query<Map<String, dynamic>> query = _db
        .collection('audits_history')
        .orderBy(FieldPath.documentId)
        .limit(batchSize);

    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      final currentQuery = (lastDoc == null)
          ? query
          : query.startAfterDocument(lastDoc);
      final snapshot = await currentQuery.get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      final usedIds = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final assetId = _sanitizeDocIdPart(data['asset_id']?.toString() ?? '');
        final auditorId = _sanitizeDocIdPart(
          data['auditor_id']?.toString() ?? 'unknown',
        );
        final statusPart = _sanitizeDocIdPart(
          (data['audit_status'])?.toString() ?? '',
        );

        DateTime? auditAt;
        final rawAuditAt = data['audited_at'];
        if (rawAuditAt is Timestamp) {
          auditAt = rawAuditAt.toDate().toUtc();
        } else if (rawAuditAt is DateTime) {
          auditAt = rawAuditAt.toUtc();
        } else if (rawAuditAt != null) {
          auditAt = DateTime.tryParse(rawAuditAt.toString())?.toUtc();
        }
        auditAt ??= DateTime.now().toUtc();

        final String timestampStr =
            "${auditAt.year}${auditAt.month.toString().padLeft(2, '0')}${auditAt.day.toString().padLeft(2, '0')}-"
            "${auditAt.hour.toString().padLeft(2, '0')}${auditAt.minute.toString().padLeft(2, '0')}${auditAt.second.toString().padLeft(2, '0')}-"
            "${auditAt.millisecond.toString().padLeft(3, '0')}";

        final auditorShort = auditorId.length <= 6
            ? auditorId
            : auditorId.substring(0, 6);
        String newId =
            "${assetId.isEmpty ? 'unknown_asset' : assetId}_$timestampStr"
            "${statusPart.isEmpty ? '' : '_s$statusPart'}"
            "_${auditorShort.isEmpty ? 'unknown' : auditorShort}";

        if (newId == doc.id) {
          continue;
        }

        if (usedIds.contains(newId)) {
          int dup = 2;
          while (usedIds.contains('${newId}_dup$dup')) {
            dup++;
          }
          newId = '${newId}_dup$dup';
        }
        usedIds.add(newId);

        final newRef = _db.collection('audits_history').doc(newId);
        batch.set(newRef, data);
        if (deleteOld) {
          batch.delete(doc.reference);
        }
        migratedCount++;
      }

      await batch.commit();
      lastDoc = snapshot.docs.last;
    }

    return migratedCount;
  }

  Future<void> createReport(
    Map<String, dynamic> report, {
    bool shouldCreateAuditLog = true,
  }) async {
    final now = DateTime.now();
    final String timestampStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}-"
        "${now.millisecond.toString().padLeft(3, '0')}";

    final String assetId = report['asset_id'].toString();
    final String customDocId = "${assetId}_$timestampStr";

    final sanitizedReport = Map<String, dynamic>.from(report);
    sanitizedReport.remove('issue');

    final normalizedReport = _normalizeReportWriteData(sanitizedReport);
    final int reportStatusCode = reportStatusToCode(
      normalizedReport['report_status'],
    );

    // Prevent duplicate open reports for same asset (pending/repairing).
    // We only enforce this when creating a new pending report.
    if (reportStatusCode == 1) {
      final hasOpen = await hasOpenReportForAsset(assetId);
      if (hasOpen) {
        throw Exception('DUPLICATE_OPEN_REPORT');
      }
    }

    if (!normalizedReport.containsKey('asset_name') ||
        (normalizedReport['asset_name']?.toString().trim().isEmpty ?? true)) {
      try {
        Map<String, dynamic>? assetData;
        try {
          final doc = await _db.collection('assets').doc(assetId).get();
          assetData = doc.data();
        } catch (_) {}

        if (assetData == null) {
          final snapshot = await _db
              .collection('assets')
              .where('asset_id', isEqualTo: assetId)
              .limit(1)
              .get();
          if (snapshot.docs.isNotEmpty) {
            assetData = snapshot.docs.first.data();
          }
        }

        final an = assetData?['asset_name']?.toString();
        if (an != null && an.trim().isNotEmpty) {
          normalizedReport['asset_name'] = an.trim();
        }
      } catch (e) {
        debugPrint('Error resolving asset_name for report: $e');
      }
    }

    if (reportStatusCode != 4) {
      normalizedReport.remove('remark_broken');
      normalizedReport.remove('broken_image_url');
    }

    await _db.collection('reports_history').doc(customDocId).set({
      ...normalizedReport,
      if (!report.containsKey('reported_at'))
        'reported_at': FieldValue.serverTimestamp(),
      'report_status': reportStatusCode,
    });

    if (shouldCreateAuditLog) {
      int auditStatus = 2;
      if (reportStatusCode == 2) auditStatus = 3;
      if (reportStatusCode == 3) auditStatus = 1;
      if (reportStatusCode == 4) auditStatus = 4;

      final auditorId =
          report['reporter_id']?.toString().trim().isNotEmpty == true
          ? report['reporter_id'].toString().trim()
          : 'unknown_uid';

      await createAuditLog({
        'asset_id': assetId,
        'auditor_id': auditorId,
        if (report['reporter_name']?.toString().trim().isNotEmpty == true)
          'auditor_name': report['reporter_name']?.toString().trim(),
        'audit_status': auditStatus,
      });
    }
  }

  Future<String> createRepairAgainReport({
    required String assetId,
    required String previousReportId,
    required String reason,
    required String workerId,
    required String workerName,
    String? reportImageUrl,
  }) async {
    String? resolvedAssetName;
    try {
      Map<String, dynamic>? assetData;
      try {
        final doc = await _db.collection('assets').doc(assetId).get();
        assetData = doc.data();
      } catch (_) {}

      if (assetData == null) {
        final snapshot = await _db
            .collection('assets')
            .where('asset_id', isEqualTo: assetId)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          assetData = snapshot.docs.first.data();
        }
      }

      final an = assetData?['asset_name']?.toString();
      if (an != null && an.trim().isNotEmpty) {
        resolvedAssetName = an.trim();
      }
    } catch (e) {
      debugPrint('Error resolving asset_name for repair again report: $e');
    }

    final now = DateTime.now();
    final String timestampStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}-"
        "${now.millisecond.toString().padLeft(3, '0')}";

    final String customDocId = "${assetId}_$timestampStr";

    await _db.collection('reports_history').doc(customDocId).set({
      'asset_id': assetId,
      if (resolvedAssetName != null) 'asset_name': resolvedAssetName,
      'report_remark': reason,
      'reporter_id': workerId,
      'reporter_name': workerName,
      'reported_at': FieldValue.serverTimestamp(),
      'report_status': 2,
      'worker_id': workerId,
      'worker_name': workerName,
      'start_repair_at': FieldValue.serverTimestamp(),
      'report_id': previousReportId,
      if (reportImageUrl != null && reportImageUrl.trim().isNotEmpty)
        'report_image_url': reportImageUrl.trim(),
    });

    return customDocId;
  }

  // Get reports history stream with optional filters
  Stream<List<Map<String, dynamic>>> getReportsHistoryStream({
    int? statusFilter,
    String? reporterId,
  }) {
    Query query = _db.collection('reports_history');

    if (reporterId != null) {
      query = query.where('reporter_id', isEqualTo: reporterId);
    }

    return query.snapshots().map((snapshot) {
      final mapped = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID to data
        return data;
      }).toList();

      if (statusFilter == null) return mapped;

      return mapped.where((data) {
        final code = reportStatusToCode(
          data['report_status'] ?? data['status'],
        );
        return code == statusFilter;
      }).toList();
    });
  }

  // Get single report by document ID
  Future<Map<String, dynamic>?> getReportHistoryById(String docId) async {
    final doc = await _db.collection('reports_history').doc(docId).get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  // Update report status with additional data
  Future<void> updateReportStatus(
    String docId,
    int newStatus, {
    Map<String, dynamic>? extraData,
  }) async {
    final normalizedExtra = extraData == null
        ? null
        : _normalizeReportWriteData(extraData);
    final updateData = <String, dynamic>{
      'report_status': newStatus,
      ...?normalizedExtra,
    };
    await _db.collection('reports_history').doc(docId).update(updateData);
  }

  // อัปโหลดรูปภาพรายงานปัญหา
  Future<String?> uploadReportImage(File image, String assetId) async {
    try {
      String fileName =
          'report_${assetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(
        'report_images/$fileName',
      );
      UploadTask uploadTask = ref.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading report image: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAssetById(String assetId) async {
    try {
      final trimmed = assetId.toString().trim();
      if (trimmed.isEmpty) return null;

      // Sanitize ID to prevent "Invalid document reference" crash
      final safeId = _sanitizeDocId(trimmed);
      final doc = await _db.collection('assets').doc(safeId).get();
      if (doc.exists) return doc.data();

      // Fallback: docId may not be asset_id
      final snapshot = await _db
          .collection('assets')
          .where('asset_id', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }

      return null;
    } catch (e) {
      debugPrint('Firebase getAssetById Error: $e');
      return null;
    }
  }

  /// Sanitize asset_id for use as Firestore document ID
  /// Firestore doc IDs cannot contain "/" — replace with "_"
  String _sanitizeDocId(String id) => id.replaceAll('/', '_');

  Future<bool> isAssetIdAvailable(
    String assetId, {
    String? excludeDocId,
  }) async {
    try {
      final trimmed = assetId.toString().trim();
      if (trimmed.isEmpty) return false;

      final exclude = excludeDocId?.toString().trim();
      final safeDocId = _sanitizeDocId(trimmed);

      final doc = await _db.collection('assets').doc(safeDocId).get();
      if (doc.exists && doc.id != exclude) return false;

      final snapshot = await _db
          .collection('assets')
          .where('asset_id', isEqualTo: trimmed)
          .limit(5)
          .get();

      for (final d in snapshot.docs) {
        if (exclude != null && d.id == exclude) continue;
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('isAssetIdAvailable error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCheckLogs(String assetId) async {
    try {
      // Remove orderBy to avoid "Failed Precondition: The query requires an index" error
      final snapshot = await _db
          .collection('audits_history')
          .where('asset_id', isEqualTo: assetId)
          .get();

      final docs = snapshot.docs.map((doc) => doc.data()).toList();

      // Sort client-side: Newest first
      docs.sort((a, b) {
        final tA = (a['audited_at'] ?? a['audit_at']) as Timestamp?;
        final tB = (b['audited_at'] ?? b['audit_at']) as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });

      debugPrint('✅ Fetched ${docs.length} audit logs for $assetId');
      return docs;
    } catch (e) {
      debugPrint('🚨 Error fetching audit logs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReports(String assetId) async {
    try {
      // Avoid composite-index requirement by not combining where(...) with orderBy(...).
      final snapshot = await _db
          .collection('reports_history')
          .where('asset_id', isEqualTo: assetId)
          .get();

      final docs = snapshot.docs.toList();
      docs.sort((a, b) => b.id.compareTo(a.id));

      return docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('🚨 Firebase getReports Error (likely missing index): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllCheckLogs() async {
    final snapshot = await _db
        .collection('check_logs')
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      // Avoid orderBy to reduce index/type issues; sort client-side by docId.
      final snapshot = await _db.collection('reports_history').get();

      final docs = snapshot.docs.toList();
      docs.sort((a, b) => b.id.compareTo(a.id));

      return docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Firebase getAllReports Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReportsByReporter(
    String reporterName,
  ) async {
    try {
      final snapshot = await _db
          .collection('reports_history')
          .where('reporter_name', isEqualTo: reporterName)
          .get();

      final docs = snapshot.docs.map((doc) => doc.data()).toList();
      docs.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        DateTime? dA;
        DateTime? dB;
        if (tA is Timestamp) dA = tA.toDate();
        if (tB is Timestamp) dB = tB.toDate();
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return dB.compareTo(dA);
      });
      return docs;
    } catch (e) {
      debugPrint('Firebase getReportsByReporter Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReportsByReporterId(
    String reporterId,
  ) async {
    try {
      final id = reporterId.trim();
      if (id.isEmpty) return [];

      final snapshot = await _db
          .collection('reports_history')
          .where('reporter_id', isEqualTo: id)
          .get();

      final docs = snapshot.docs.toList();

      // Our reports_history docId includes a sortable timestamp suffix.
      docs.sort((a, b) => b.id.compareTo(a.id));

      return docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Firebase getReportsByReporterId Error: $e');
      return [];
    }
  }

  Future<UserModel?> getUserProfileByEmail(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return UserModel.fromFirestore(doc.data(), doc.id);
    }
    return null;
  }

  // --- Admin User Management ---

  /// Get all users from Firestore (Stream)
  Stream<List<UserModel>> getUsersStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// Update user role
  Future<bool> updateUserRole(String uid, int newRole) async {
    try {
      await _db.collection('users').doc(uid).update({'role': newRole});
      return true;
    } catch (e) {
      debugPrint('Firebase updateUserRole Error: $e');
      return false;
    }
  }

  /// Approve user
  Future<bool> approveUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({'is_approved': true});
      return true;
    } catch (e) {
      debugPrint('Firebase approveUser Error: $e');
      return false;
    }
  }

  /// Delete user
  Future<bool> deleteUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
      return true;
    } catch (e) {
      debugPrint('Firebase deleteUser Error: $e');
      return false;
    }
  }

  /// Approve multiple users
  Future<bool> approveMultipleUsers(List<String> uids) async {
    try {
      final batch = _db.batch();
      for (var uid in uids) {
        batch.update(_db.collection('users').doc(uid), {'is_approved': true});
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Firebase approveMultipleUsers Error: $e');
      return false;
    }
  }
  // --- Locations Management ---

  Stream<List<Map<String, dynamic>>> getLocationsStream() {
    return _db.collection('locations').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<bool> addLocation({
    required String locationId,
    required String roomName,
    required int floor,
    String building = 'ตึกกิจการนักศึกษา',
  }) async {
    try {
      await _db.collection('locations').doc(locationId).set({
        'location_id': locationId,
        'room_name': roomName,
        'floor': floor,
        'building': building,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding location: $e');
      return false;
    }
  }

  Future<bool> updateLocation(
    String locationId, {
    required String roomName,
    required int floor,
  }) async {
    try {
      await _db.collection('locations').doc(locationId).update({
        'room_name': roomName,
        'floor': floor,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating location: $e');
      return false;
    }
  }

  Future<bool> deleteLocation(String locationId) async {
    try {
      await _db.collection('locations').doc(locationId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting location: $e');
      return false;
    }
  }

  // --- Asset Categories Management ---

  Stream<List<Map<String, dynamic>>> getAssetCategoriesStream() {
    return _db.collection('asset_categories').orderBy('order').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getAssetCategories() async {
    final snapshot = await _db
        .collection('asset_categories')
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<bool> addAssetCategory(String categoryName) async {
    try {
      final snapshot = await _db
          .collection('asset_categories')
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      int nextOrder = 1;
      if (snapshot.docs.isNotEmpty) {
        nextOrder = (snapshot.docs.first.data()['order'] as int) + 1;
      }

      String docId = 'category_$nextOrder';

      await _db.collection('asset_categories').doc(docId).set({
        'name': categoryName,
        'order': nextOrder,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding asset category: $e');
      return false;
    }
  }

  Future<bool> deleteAssetCategory(String docId) async {
    try {
      await _db.collection('asset_categories').doc(docId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting asset category: $e');
      return false;
    }
  }

  // Initialize default categories
  Future<bool> initializeDefaultCategories() async {
    try {
      final snapshot = await _db.collection('asset_categories').limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Categories already exist, skipping initialization');
        return true;
      }

      final defaultCategories = [
        {'id': 'computer', 'name': 'ครุภัณฑ์คอมพิวเตอร์และระบบเครือข่าย'},
        {'id': 'office', 'name': 'ครุภัณฑ์สำนักงานและเฟอร์นิเจอร์'},
        {'id': 'electrical', 'name': 'ครุภัณฑ์ไฟฟ้าและเครื่องปรับอากาศ'},
        {'id': 'education', 'name': 'ครุภัณฑ์การศึกษาและโสตทัศนูปกรณ์'},
        {'id': 'engineering', 'name': 'เครื่องมือวัดและอุปกรณ์ทางวิศวกรรม'},
        {'id': 'broadcast', 'name': 'อุปกรณ์กระจายเสียงและภาพ'},
      ];

      for (int i = 0; i < defaultCategories.length; i++) {
        final cat = defaultCategories[i];
        String docId = 'category_${i + 1}';

        await _db.collection('asset_categories').doc(docId).set({
          'name': cat['name'],
          'order': i + 1,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Default asset categories initialized!');
      return true;
    } catch (e) {
      debugPrint('Error initializing categories: $e');
      return false;
    }
  }

  // --- Asset Management with Image Upload ---

  Future<String?> uploadAssetImage(File imageFile, String assetId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('assets')
          .child('$assetId.jpg');

      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading asset image: $e');
      return null;
    }
  }

  Future<bool> addAsset({
    required String assetId,
    required String assetName,
    required String assetType,
    required String permanentId,
    required dynamic price,
    required dynamic locationId,
    String? createdId,
    String? createdBy,
    DateTime? purchaseAt,
    File? imageFile,
  }) async {
    try {
      final trimmedAssetId = assetId.toString().trim();
      if (trimmedAssetId.isEmpty) return false;

      final trimmedPermanentId = permanentId.toString().trim();
      if (trimmedPermanentId.isEmpty) return false;

      final available = await isAssetIdAvailable(trimmedAssetId);
      if (!available) {
        debugPrint('addAsset blocked: duplicate asset_id=$trimmedAssetId');
        return false;
      }

      final pDoc = await _db
          .collection('assets_permanent')
          .doc(trimmedPermanentId)
          .get();
      if (!pDoc.exists) {
        debugPrint(
          'addAsset blocked: permanent_id not found=$trimmedPermanentId',
        );
        return false;
      }
      final permanentValidation = await validatePermanentIdForNewAsset(
        trimmedPermanentId,
      );
      if (permanentValidation != null) {
        debugPrint('addAsset blocked: $permanentValidation');
        return false;
      }

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadAssetImage(imageFile, trimmedAssetId);
      }

      String? roomName;
      try {
        final locId = locationId?.toString();
        if (locId != null && locId.trim().isNotEmpty) {
          final locDoc = await _db
              .collection('locations')
              .doc(locId.trim())
              .get();
          final locData = locDoc.data();
          final rn = locData?['room_name']?.toString();
          if (rn != null && rn.trim().isNotEmpty) {
            roomName = rn.trim();
          }
        }
      } catch (e) {
        debugPrint('Error reading location room_name: $e');
      }

      final data = <String, dynamic>{
        'asset_id': trimmedAssetId,
        'asset_name': assetName,
        'asset_type': assetType,
        'permanent_id': trimmedPermanentId,
        'price': price,
        'location_id': locationId,
        if (roomName != null) 'location_name': roomName,
        'asset_status': 1,
        'asset_image_url': imageUrl,
        if (createdId != null) 'created_id': createdId,
        if (createdBy != null) 'created_name': createdBy,
        if (purchaseAt != null) 'purchase_at': Timestamp.fromDate(purchaseAt),
        'created_at': FieldValue.serverTimestamp(),
      };

      final safeDocId = _sanitizeDocId(trimmedAssetId);
      await _db.runTransaction((tx) async {
        final ref = _db.collection('assets').doc(safeDocId);
        final existing = await tx.get(ref);
        if (existing.exists) {
          throw StateError('duplicate-asset-id');
        }

        final pRef = _db.collection('assets_permanent').doc(trimmedPermanentId);
        final pDocTx = await tx.get(pRef);
        if (!pDocTx.exists) {
          throw StateError('permanent-not-found');
        }

        tx.set(ref, data);
      });

      return true;
    } catch (e) {
      debugPrint('Error adding asset: $e');
      return false;
    }
  }

  // --- Bulk Import Assets from CSV ---

  /// Result class for each row in bulk import
  /// [success] = true means the asset was added successfully
  /// [error] = error message if failed
  /// [assetId] = the asset_id from the row

  /// Add multiple assets at once from parsed CSV data.
  /// Each row is a Map with keys: asset_id, asset_name, asset_type,
  /// permanent_id, price, location_id, purchase_date
  /// Returns a list of result maps: {row, asset_id, success, error}
  Future<List<Map<String, dynamic>>> addAssetBulk({
    required List<Map<String, String>> rows,
    String? createdId,
    String? createdBy,
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <Map<String, dynamic>>[];

    // Pre-fetch location room names
    final locationSnapshot = await _db.collection('locations').get();
    final locationRoomNames = <String, String>{};
    for (final doc in locationSnapshot.docs) {
      final rn = doc.data()['room_name']?.toString() ?? '';
      if (rn.trim().isNotEmpty) {
        locationRoomNames[doc.id] = rn.trim();
      }
    }

    // Collect all asset IDs from the CSV to check duplicates within the file
    final csvAssetIds = <String>{};

    // Process each row
    final batchDocs = <Map<String, dynamic>>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final assetId = (row['asset_id'] ?? '').trim();
      final assetName = (row['asset_name'] ?? '').trim();
      final assetType = (row['asset_type'] ?? '').trim();
      final permanentId = (row['permanent_id'] ?? '').trim();
      final priceStr = (row['price'] ?? '').trim();
      final locationId = (row['location_id'] ?? '').trim();
      final purchaseDateStr = (row['purchase_date'] ?? '').trim();

      // Validate required fields
      if (assetId.isEmpty) {
        results.add({
          'row': i + 1,
          'asset_id': assetId,
          'success': false,
          'error': 'รหัสครุภัณฑ์ว่าง',
        });
        onProgress?.call(i + 1, rows.length);
        continue;
      }
      if (assetName.isEmpty) {
        results.add({
          'row': i + 1,
          'asset_id': assetId,
          'success': false,
          'error': 'ชื่อครุภัณฑ์ว่าง',
        });
        onProgress?.call(i + 1, rows.length);
        continue;
      }
      if (permanentId.isEmpty) {
        results.add({
          'row': i + 1,
          'asset_id': assetId,
          'success': false,
          'error': 'กลุ่มสินทรัพย์ถาวรว่าง',
        });
        onProgress?.call(i + 1, rows.length);
        continue;
      }
      // Check duplicate within CSV file
      if (csvAssetIds.contains(assetId)) {
        results.add({
          'row': i + 1,
          'asset_id': assetId,
          'success': false,
          'error': 'รหัสครุภัณฑ์ซ้ำในไฟล์ CSV',
        });
        onProgress?.call(i + 1, rows.length);
        continue;
      }
      csvAssetIds.add(assetId);

      // Check if asset_id already exists in Firestore
      final available = await isAssetIdAvailable(assetId);
      if (!available) {
        results.add({
          'row': i + 1,
          'asset_id': assetId,
          'success': false,
          'error': 'รหัสครุภัณฑ์นี้มีอยู่แล้วในระบบ',
        });
        onProgress?.call(i + 1, rows.length);
        continue;
      }

      // Parse price
      double? price;
      if (priceStr.isNotEmpty) {
        final cleaned = priceStr.replaceAll(',', '').replaceAll(' ', '');
        price = double.tryParse(cleaned);
      }

      // Parse purchase date - supports YYYY-MM-DD, D/M/YYYY, DD/MM/YYYY, D-M-YYYY
      DateTime? purchaseDate;
      if (purchaseDateStr.isNotEmpty) {
        // Try ISO 8601 first (YYYY-MM-DD)
        purchaseDate = DateTime.tryParse(purchaseDateStr);
        if (purchaseDate == null) {
          // Try D/M/YYYY or DD/MM/YYYY (common Excel format)
          final slashParts = purchaseDateStr.split(RegExp(r'[/\-]'));
          if (slashParts.length == 3) {
            final d = int.tryParse(slashParts[0]);
            final m = int.tryParse(slashParts[1]);
            final y = int.tryParse(slashParts[2]);
            if (d != null &&
                m != null &&
                y != null &&
                m >= 1 &&
                m <= 12 &&
                d >= 1 &&
                d <= 31) {
              // Handle Buddhist Era year (พ.ศ.) - if year > 2400, subtract 543
              final ceYear = y > 2400 ? y - 543 : y;
              purchaseDate = DateTime(ceYear, m, d);
            }
          }
        }
      }

      // Resolve location room name
      final roomName = locationRoomNames[locationId];

      final data = <String, dynamic>{
        'asset_id': assetId,
        'asset_name': assetName,
        'asset_type': assetType,
        'permanent_id': permanentId,
        'price': price,
        'location_id': locationId.isNotEmpty ? locationId : '1',
        if (roomName != null) 'location_name': roomName,
        'asset_status': 1,
        'asset_image_url': null,
        if (createdId != null) 'created_id': createdId,
        if (createdBy != null) 'created_name': createdBy,
        if (purchaseDate != null)
          'purchase_at': Timestamp.fromDate(purchaseDate),
        'created_at': FieldValue.serverTimestamp(),
      };

      batchDocs.add({'assetId': assetId, 'row': i + 1, 'data': data});

      onProgress?.call(i + 1, rows.length);
    }

    // Write valid docs in batches of 400 (Firestore limit is 500)
    for (int start = 0; start < batchDocs.length; start += 400) {
      final end = (start + 400 > batchDocs.length)
          ? batchDocs.length
          : start + 400;
      final chunk = batchDocs.sublist(start, end);

      final batch = _db.batch();
      for (final item in chunk) {
        final safeId = _sanitizeDocId(item['assetId'] as String);
        final ref = _db.collection('assets').doc(safeId);
        batch.set(ref, item['data'] as Map<String, dynamic>);
      }

      try {
        await batch.commit();
        for (final item in chunk) {
          results.add({
            'row': item['row'],
            'asset_id': item['assetId'],
            'success': true,
            'error': null,
          });
        }
      } catch (e) {
        debugPrint('Bulk import batch error: $e');
        for (final item in chunk) {
          results.add({
            'row': item['row'],
            'asset_id': item['assetId'],
            'success': false,
            'error': 'Batch write error: $e',
          });
        }
      }
    }

    // Sort results by row number
    results.sort((a, b) => (a['row'] as int).compareTo(b['row'] as int));
    return results;
  }

  Future<Map<String, int>> getAssetStats() async {
    try {
      final assetsRef = _db.collection('assets');

      final totalSnapshot = await assetsRef.count().get();
      final total = totalSnapshot.count ?? 0;

      final normalSnapshot = await assetsRef
          .where('asset_status', whereIn: [1, '1', 'ปกติ'])
          .count()
          .get();
      final normal = normalSnapshot.count ?? 0;

      final pendingSnapshot = await assetsRef
          .where('asset_status', whereIn: [2, '2', 'อยู่ระหว่างซ่อม'])
          .count()
          .get();
      final pending = pendingSnapshot.count ?? 0;

      final damagedSnapshot = await assetsRef
          .where(
            'asset_status',
            whereIn: [0, '0', 'ชำรุด', 4, '4', 'ซ่อมไม่ได้'],
          )
          .count()
          .get();
      final damaged = damagedSnapshot.count ?? 0;

      return {
        'total': total,
        'normal': normal,
        'pending': pending,
        'damaged': damaged,
      };
    } catch (e) {
      debugPrint('Firebase getAssetStats Error: $e');
      return {'total': 0, 'normal': 0, 'pending': 0, 'damaged': 0};
    }
  }

  // --- Reports ---
  Future<List<Map<String, dynamic>>> getMyReports(String reporterName) async {
    try {
      final snapshot = await _db
          .collection('reports_history')
          .where('reporter_name', isEqualTo: reporterName)
          .get();

      final docs = snapshot.docs.map((doc) => doc.data()).toList();
      docs.sort((a, b) {
        final tA = a['reported_at'] ?? a['timestamp'];
        final tB = b['reported_at'] ?? b['timestamp'];
        DateTime? dA;
        DateTime? dB;
        if (tA is Timestamp) dA = tA.toDate();
        if (tB is Timestamp) dB = tB.toDate();
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return dB.compareTo(dA);
      });
      return docs;
    } catch (e) {
      debugPrint('Firebase getMyReports Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAssetsByLocation(
    dynamic locationId,
  ) async {
    try {
      final snapshot = await _db
          .collection('assets')
          .where('location_id', isEqualTo: locationId)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Firebase getAssetsByLocation Error: $e');
      return [];
    }
  }

  // --- Username/Password Authentication ---

  /// Login with username and password
  /// Returns UserModel if successful, null if credentials are invalid
  Future<UserModel?> loginWithUsernamePassword(
    String username,
    String password,
  ) async {
    try {
      final trimmedUsername = username.trim().toLowerCase();
      final trimmedPassword = password.trim();

      if (trimmedUsername.isEmpty || trimmedPassword.isEmpty) {
        return null;
      }

      // Query users by username
      final snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: trimmedUsername)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('Login failed: Username not found');
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();

      // Check password (plain text comparison for demo)
      final storedPassword = data['password']?.toString() ?? '';
      if (storedPassword != trimmedPassword) {
        debugPrint('Login failed: Incorrect password');
        return null;
      }

      // Return user model
      return UserModel.fromFirestore(data, doc.id);
    } catch (e) {
      debugPrint('loginWithUsernamePassword Error: $e');
      return null;
    }
  }

  /// Ensure admin account exists in Firestore
  /// Creates default admin: username="admin", password="123456"
  Future<void> ensureAdminAccountExists() async {
    try {
      // Check if admin account already exists
      final snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint('Admin account already exists');
        return;
      }

      // Create admin account with a generated UID
      final adminUid = 'admin_${DateTime.now().millisecondsSinceEpoch}';

      await _db.collection('users').doc(adminUid).set({
        'uid': adminUid,
        'username': 'admin',
        'password': '123456',
        'email': 'admin@rmutp.ac.th',
        'fullname': 'Administrator',
        'role': 1, // Admin
        'is_approved': true,
        'position': 'System Administrator',
        'created_at': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Admin account created successfully');
    } catch (e) {
      debugPrint('ensureAdminAccountExists Error: $e');
    }
  }

  /// Search asset by partial ID (for QR code flexibility)
  Future<Map<String, dynamic>?> searchAssetByPartialId(String partialId) async {
    try {
      final trimmed = partialId.trim();
      if (trimmed.isEmpty) return null;

      // ค้นหาด้วย asset_id เต็ม
      final exactMatch = await getAssetById(trimmed);
      if (exactMatch != null) return exactMatch;

      // ดึง assets ทั้งหมดและค้นหาแบบ contains
      final snapshot = await _db.collection('assets').get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docAssetId = data['asset_id']?.toString() ?? '';

        // ตรวจสอบว่า asset_id ที่ scan มาตรงกับใน database หรือไม่
        if (docAssetId == trimmed) {
          return data;
        }

        // ตรวจสอบว่า contains กัน (กรณี format ต่างกันเล็กน้อย)
        if (docAssetId.contains(trimmed) || trimmed.contains(docAssetId)) {
          debugPrint('🔍 พบ partial match: $docAssetId ≈ $trimmed');
          return data;
        }

        // ตรวจสอบ document ID
        if (doc.id == trimmed ||
            doc.id.contains(trimmed) ||
            trimmed.contains(doc.id)) {
          debugPrint('🔍 พบ doc ID match: ${doc.id} ≈ $trimmed');
          return data;
        }
      }

      return null;
    } catch (e) {
      debugPrint('searchAssetByPartialId error: $e');
      return null;
    }
  }
}
