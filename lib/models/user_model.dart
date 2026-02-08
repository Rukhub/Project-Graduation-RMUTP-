import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullname;
  final int role; // 0 = User, 1 = Admin
  final bool isApproved;
  final String? photoUrl;
  final String? username; // Keep for compatibility if needed
  final String? position; // Keep for compatibility if needed

  UserModel({
    required this.uid,
    required this.email,
    required this.fullname,
    required this.role,
    required this.isApproved,
    this.photoUrl,
    this.username,
    this.position,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      email: data['email'] ?? '',
      fullname: data['fullname'] ?? '',
      role: data['role'] is int ? data['role'] : int.tryParse(data['role']?.toString() ?? '0') ?? 0,
      isApproved: data['is_approved'] == true,
      photoUrl: data['photo_url'],
      username: data['username'],
      position: data['position'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'fullname': fullname,
      'role': role,
      'is_approved': isApproved,
      'photo_url': photoUrl,
      'username': username,
      'position': position,
      'created_at': FieldValue.serverTimestamp(), // Added to match Bo's screenshot if possible
    };
  }
}
