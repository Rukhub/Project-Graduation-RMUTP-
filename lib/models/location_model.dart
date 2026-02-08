class LocationModel {
  final dynamic locationId;
  final String floor;
  final String roomName;

  LocationModel({
    required this.locationId,
    required this.floor,
    required this.roomName,
  });

  factory LocationModel.fromFirestore(Map<String, dynamic> data, dynamic id) {
    return LocationModel(
      locationId: id,
      floor: data['floor']?.toString() ?? '',
      roomName: data['room_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'floor': floor,
      'room_name': roomName,
    };
  }
}
