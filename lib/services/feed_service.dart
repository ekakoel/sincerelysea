import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/feed_model.dart';
import '../models/comment_model.dart';

class FeedService {
  final _db = FirebaseFirestore.instance;

  // Stream<List<FeedModel>> getFeeds() {
  //   return _db
  //       .collection('feeds')
  //       .snapshots(includeMetadataChanges: true) // Agar update lokal langsung muncul
  //       .map((snapshot) {
  //     final feeds = snapshot.docs
  //         .map((doc) {
  //           try {
  //             return FeedModel.fromFirestore(doc.data(), doc.id);
  //           } catch (e) {
  //             return null; // Skip dokumen yang rusak/error
  //           }
  //         })
  //         .where((e) => e != null) // Filter null
  //         .cast<FeedModel>()
  //         .toList();
  //     // Sort DESCENDING (Terbaru di atas): b.createdAt.compareTo(a.createdAt)
  //     feeds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  //     return feeds;
  //   });
  // }
  Stream<List<FeedModel>> getFeeds() {
  return _db
      .collection('feeds')
      .snapshots() // ⬅️ HAPUS includeMetadataChanges
      .map((snapshot) {
        final feeds = snapshot.docs
            .map((doc) => FeedModel.fromFirestore(doc.data(), doc.id))
            .toList();

        feeds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return feeds;
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
        .orderBy('createdAt', descending: false) // Fetch oldest first to build hierarchy
        .snapshots()
        .map((snapshot) {
      final allComments = snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc.data(), doc.id))
          .toList();

      final Map<String, CommentModel> commentMap = {
        for (var c in allComments) c.id: c
      };
      final List<CommentModel> topLevelComments = [];

      for (var comment in allComments) {
        if (comment.parentId != null && commentMap.containsKey(comment.parentId)) {
          // This is a reply, add it to the parent's list
          commentMap[comment.parentId]!.replies.add(comment);
        } else {
          // This is a top-level comment
          topLevelComments.add(comment);
        }
      }
      
      // Optional: Sort replies by creation time as well
      for (var comment in topLevelComments) {
        comment.replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }

      // Sort top-level comments to show newest first
      topLevelComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return topLevelComments;
    });
  }

  Future<void> addComment(String feedId, String uid, String userName, String text, {String? parentId}) async {
    final commentData = {
      'uid': uid,
      'userName': userName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'parentId': parentId,
    };
    // Remove parentId if it's null, so it doesn't get saved in Firestore
    if (parentId == null) {
      commentData.remove('parentId');
    }
    
    await _db.collection('feeds').doc(feedId).collection('comments').add(commentData);

    await _db.collection('feeds').doc(feedId).update({
      'commentCount': FieldValue.increment(1),
    });
  }
}
