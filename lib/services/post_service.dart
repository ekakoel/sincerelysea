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
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      // 1. Upload Image to Firebase Storage
      // Create a unique filename based on timestamp
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final Reference ref = _storage.ref().child('posts/$uid/$fileName.jpg');
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Extract hashtags from caption
      final List<String> hashtags = RegExp(r"#[a-zA-Z0-9_]+")
          .allMatches(caption)
          .map((m) => m.group(0)!)
          .toList();

      // 2. Save Post Data to Firestore 'feeds' collection
      await _firestore.collection('feeds').add({
        'uid': uid,
        'userName': userName,
        'imageUrl': downloadUrl,
        'caption': caption,
        'hashtags': hashtags,
        'likes': [],
        'savedBy': [],
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePost(String postId, String imageUrl) async {
    try {
      // 1. Fetch post to get hashtags
      final DocumentSnapshot postDoc = await _firestore.collection('feeds').doc(postId).get();
      final List<dynamic> hashtags = (postDoc.data() as Map<String, dynamic>?)?['hashtags'] ?? [];

      // 2. Delete Image from Storage
      if (imageUrl.isNotEmpty) {
        await _storage.refFromURL(imageUrl).delete();
      }

      // 3. Decrement hashtag counts and delete post
      final WriteBatch batch = _firestore.batch();

      for (final tag in hashtags) {
        if (tag is String && tag.startsWith('#') && tag.length > 1) {
          final String tagId = tag.substring(1).toLowerCase();
          batch.update(_firestore.collection('hashtags').doc(tagId), {'count': FieldValue.increment(-1)});
        }
      }

      batch.delete(_firestore.collection('feeds').doc(postId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePostCaption(String postId, String newCaption) async {
    // 1. Fetch current post to get old hashtags
    final DocumentSnapshot postDoc = await _firestore.collection('feeds').doc(postId).get();
    if (!postDoc.exists) throw Exception('Post not found');

    final List<dynamic> oldHashtagsList = (postDoc.data() as Map<String, dynamic>?)?['hashtags'] ?? [];
    final Set<String> oldHashtags = oldHashtagsList.cast<String>().toSet();

    // 2. Extract new hashtags
    final Set<String> newHashtags = RegExp(r"#[a-zA-Z0-9_]+")
        .allMatches(newCaption)
        .map((m) => m.group(0)!)
        .toSet();

    // 3. Calculate differences
    final Set<String> tagsToAdd = newHashtags.difference(oldHashtags);
    final Set<String> tagsToRemove = oldHashtags.difference(newHashtags);

    // 4. Batch update
    final WriteBatch batch = _firestore.batch();

    batch.update(_firestore.collection('feeds').doc(postId), {
      'caption': newCaption,
      'hashtags': newHashtags.toList(),
    });

    for (final tag in tagsToAdd) {
      final String tagId = tag.substring(1).toLowerCase();
      batch.set(_firestore.collection('hashtags').doc(tagId), {'tag': tag, 'count': FieldValue.increment(1)}, SetOptions(merge: true));
    }

    for (final tag in tagsToRemove) {
      final String tagId = tag.substring(1).toLowerCase();
      batch.update(_firestore.collection('hashtags').doc(tagId), {'count': FieldValue.increment(-1)});
    }

    await batch.commit();
  }

  Future<List<String>> fetchHashtags() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('hashtags').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['tag'] as String? ?? '';
      }).where((tag) => tag.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> toggleLike(String postId, String uid, String postOwnerUid, List likes) async {
    final DocumentReference postRef = _firestore.collection('feeds').doc(postId);

    if (likes.contains(uid)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([uid])
      });
    }
  }

  Future<void> toggleSave(String postId, String uid, List savedBy) async {
    final DocumentReference postRef = _firestore.collection('feeds').doc(postId);

    if (savedBy.contains(uid)) {
      await postRef.update({
        'savedBy': FieldValue.arrayRemove([uid])
      });
    } else {
      await postRef.update({
        'savedBy': FieldValue.arrayUnion([uid])
      });
    }
  }

  Future<void> toggleWishlist(String postId, String uid, List wishlistedBy) async {
    final DocumentReference postRef = _firestore.collection('feeds').doc(postId);

    if (wishlistedBy.contains(uid)) {
      await postRef.update({
        'wishlistedBy': FieldValue.arrayRemove([uid])
      });
    } else {
      await postRef.update({
        'wishlistedBy': FieldValue.arrayUnion([uid])
      });
    }
  }

  Future<void> addComment(String postId, String uid, String userName, String text, {String? parentId}) async {
    await _firestore.collection('feeds').doc(postId).collection('comments').add({
      'uid': uid,
      'userName': userName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      if (parentId != null) 'parentId': parentId,
    });

    await _firestore.collection('feeds').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _firestore
        .collection('feeds')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();

    await _firestore.collection('feeds').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  Future<void> updateComment(String postId, String commentId, String newText) async {
    await _firestore
        .collection('feeds')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> toggleCommentLike(String postId, String commentId, String uid, List likes) async {
    final DocumentReference commentRef = _firestore
        .collection('feeds')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    if (likes.contains(uid)) {
      await commentRef.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await commentRef.update({
        'likes': FieldValue.arrayUnion([uid])
      });
    }
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore
        .collection('feeds')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserPosts(String uid) {
    return _firestore
        .collection('feeds')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> followUser(String currentUid, String targetUid) async {
    final WriteBatch batch = _firestore.batch();

    // Add to current user's following collection
    DocumentReference followingRef = _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);

    // Add to target user's followers collection
    DocumentReference followerRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(currentUid);

    batch.set(followingRef, {'createdAt': FieldValue.serverTimestamp()});
    batch.set(followerRef, {'createdAt': FieldValue.serverTimestamp()});

    await batch.commit();
  }

  Future<void> unfollowUser(String currentUid, String targetUid) async {
    final WriteBatch batch = _firestore.batch();

    // Remove from current user's following collection
    DocumentReference followingRef = _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);

    // Remove from target user's followers collection
    DocumentReference followerRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(currentUid);

    batch.delete(followingRef);
    batch.delete(followerRef);

    await batch.commit();
  }

  Stream<bool> isFollowing(String currentUid, String targetUid) {
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<int> getFollowerCount(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getFollowingCount(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<List<String>> getFollowingUids(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Stream<QuerySnapshot> getPostsFromFollowedUsers(List<String> followingUids) {
    return _firestore
        .collection('feeds')
        .where('uid', whereIn: followingUids)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  Future<DocumentSnapshot> getPost(String postId) {
    return _firestore.collection('feeds').doc(postId).get();
  }
}