import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadPost({
    required String uid,
    required String userName,
    required File imageFile,
    required String caption,
  }) async {
    try {
      // 1. Upload Image to Firebase Storage
      // Create a unique filename based on timestamp
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final Reference ref = _storage.ref().child('posts/$uid/$fileName.jpg');
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Save Post Data to Firestore 'feeds' collection
      await _firestore.collection('feeds').add({
        'uid': uid,
        'userName': userName,
        'imageUrl': downloadUrl,
        'caption': caption,
        'likes': [],
        'savedBy': [],
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
}