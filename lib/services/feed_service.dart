import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/feed_model.dart';
import '../models/comment_model.dart';

class FeedService {
  final _db = FirebaseFirestore.instance;

  Stream<List<FeedModel>> getFeeds() {
    return _db
        .collection('feeds')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FeedModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<FeedModel>> getSavedFeeds(String uid) {
    return _db
        .collection('feeds')
        .where('savedBy', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FeedModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> toggleLike(String feedId, String uid, bool isLiked) async {
    final ref = _db.collection('feeds').doc(feedId);
    if (isLiked) {
      await ref.update({
        'likes': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> toggleSave(String feedId, String uid, bool isSaved) async {
    final ref = _db.collection('feeds').doc(feedId);
    if (isSaved) {
      await ref.update({
        'savedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'savedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> deleteFeed(String feedId, String imageUrl) async {
    try {
      await _db.collection('feeds').doc(feedId).delete();
      if (imageUrl.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      }
    } catch (e) {
      // Handle errors (e.g. image already deleted)
    }
  }

  Stream<List<CommentModel>> getComments(String feedId) {
    return _db
        .collection('feeds')
        .doc(feedId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addComment(String feedId, String uid, String userName, String text) async {
    await _db.collection('feeds').doc(feedId).collection('comments').add({
      'uid': uid,
      'userName': userName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('feeds').doc(feedId).update({
      'commentCount': FieldValue.increment(1),
    });
  }
}
