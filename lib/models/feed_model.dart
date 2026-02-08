import 'package:cloud_firestore/cloud_firestore.dart';

class FeedModel {
  final String id;
  final String uid;
  final String imageUrl;
  final String caption;
  final String userName;
  final List<String> likes;
  final DateTime createdAt;
  final int commentCount;
  final List<String> savedBy;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  FeedModel({
    required this.id,
    required this.uid,
    required this.imageUrl,
    required this.caption,
    required this.userName,
    required this.likes,
    required this.createdAt,
    required this.commentCount,
    required this.savedBy,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  factory FeedModel.fromFirestore(Map<String, dynamic> data, String id) {
    return FeedModel(
      id: id,
      uid: data['uid'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'] ?? '',
      userName: data['userName'] ?? 'Unknown',

      likes: (data['likes'] is List)
          ? (data['likes'] as List).map((e) => e.toString()).toList()
          : [],

      // Cek tipe data agar tidak crash jika createdAt null atau bukan Timestamp
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),

      commentCount: (data['commentCount'] is int)
          ? data['commentCount']
          : 0,

      savedBy: (data['savedBy'] is List)
          ? (data['savedBy'] as List).map((e) => e.toString()).toList()
          : [],
      latitude: data['latitude'],
      longitude: data['longitude'],
      locationName: data['locationName'],
    );
  }
}
