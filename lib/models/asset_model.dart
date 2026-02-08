class AssetModel {
  final String assetId;
  final String assetType;
  final String assetName;
  final String brandModel;
  final dynamic price;
  final dynamic locationId;
  final dynamic status; // Can be String or Int
  final String checkerName;
  final String? imageUrl;
  final String? createdBy;
  final dynamic purchaseAt; // Timestamp or String
  final dynamic createdAt;
  // ⭐ Add fallback fields for Report Info
  final String? reporterName;
  final String? issueDetail;
  final String? reportImages; // ⭐ New field for evidence images
  final String? repairerId; // ⭐ Add for repairer lock

  AssetModel({
    required this.assetId,
    required this.assetType,
    required this.assetName,
    required this.brandModel,
    required this.price,
    required this.locationId,
    required this.status,
    required this.checkerName,
    this.imageUrl,
    this.createdBy,
    this.purchaseAt,
    this.createdAt,
    this.reporterName,
    this.issueDetail,
    this.reportImages,
    this.repairerId, // ⭐ Add for repairer lock
  });

  factory AssetModel.fromFirestore(Map<String, dynamic> data) {
    final dynamic rawStatus = data['asset_status'] ?? 1;
    final String? rawImageUrl = data['asset_image_url']?.toString();
    final String createdByValue = (data['created_name'] ?? '').toString();
    final String checkerNameValue = (data['auditor_name'] ?? '').toString();

    return AssetModel(
      assetId: data['asset_id'] ?? '',
      assetType: data['asset_type'] ?? '',
      assetName: data['asset_name'] ?? data['name_asset'] ?? '',
      brandModel: data['brand_model'] ?? '',
      price: data['price'],
      locationId: data['location_id'],
      status: rawStatus,
      checkerName: checkerNameValue,
      imageUrl: rawImageUrl,
      createdBy: createdByValue.isEmpty ? null : createdByValue,
      purchaseAt: data['purchase_at'],
      createdAt: data['created_at'],
      reporterName: data['reporter_name'],
      issueDetail: data['issue_detail'],
      reportImages: data['report_images'], // ⭐ Map from Firestore
      repairerId: data['repairer_id'], // ⭐ Map from Firestore
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'asset_id': assetId,
      'asset_type': assetType,
      'asset_name': assetName,
      'brand_model': brandModel,
      'price': price,
      'location_id': locationId,
      'asset_status': status,
      'auditor_name': checkerName,
      'asset_image_url': imageUrl,
      if (createdBy != null) 'created_name': createdBy,
      'purchase_at': purchaseAt,
      'created_at': createdAt ?? DateTime.now(),
      if (repairerId != null) 'repairer_id': repairerId, // ⭐ Only save if not null
    };
  }
}
