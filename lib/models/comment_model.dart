import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String uid;
  final String userName;
  final String text;
  final DateTime createdAt;
  final String? parentId; // ID of the comment this one is replying to
  final List<CommentModel> replies; // Client-side only

  CommentModel({
    required this.id,
    required this.uid,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.replies = const [],
  });

  factory CommentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CommentModel(
      id: id,
      uid: data['uid'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentId: data['parentId'],
    );
  }
}