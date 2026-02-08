import 'package:cloud_firestore/cloud_firestore.dart';

class PostService {
  final _db = FirebaseFirestore.instance;

  // ================= FOLLOW =================

  Stream<bool> isFollowing(String currentUid, String targetUid) {
    return _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<int> getFollowerCount(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<int> getFollowingCount(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snap) => snap.size);
  }

  Future<void> followUser(String currentUid, String targetUid) async {
    final batch = _db.batch();

    batch.set(
      _db.collection('users').doc(currentUid).collection('following').doc(targetUid),
      {'createdAt': FieldValue.serverTimestamp()},
    );

    batch.set(
      _db.collection('users').doc(targetUid).collection('followers').doc(currentUid),
      {'createdAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  Future<void> unfollowUser(String currentUid, String targetUid) async {
    final batch = _db.batch();

    batch.delete(
      _db.collection('users').doc(currentUid).collection('following').doc(targetUid),
    );

    batch.delete(
      _db.collection('users').doc(targetUid).collection('followers').doc(currentUid),
    );

    await batch.commit();
  }

  // ================= POSTS =================

  Stream<QuerySnapshot> getUserPosts(String uid) {
    return _db
        .collection('feeds')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ================= SAVE / BOOKMARK =================

  Stream<QuerySnapshot> getSavedPosts(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> toggleSave(
    String postId,
    String uid,
    Map<String, dynamic> postData,
  ) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .doc(postId);

    final doc = await ref.get();

    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'imageUrl': postData['imageUrl'],
        'createdAt': FieldValue.serverTimestamp(),
        'postRef': _db.collection('feeds').doc(postId),
      });
    }
  }

  // ================= WISHLIST =================

  Stream<QuerySnapshot> getWishlistPosts(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('wishlist_posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> toggleWishlist(
    String postId,
    String uid,
    Map<String, dynamic> postData,
  ) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('wishlist_posts')
        .doc(postId);

    final doc = await ref.get();

    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'imageUrl': postData['imageUrl'],
        'createdAt': FieldValue.serverTimestamp(),
        'postRef': _db.collection('feeds').doc(postId),
      });
    }
  }
}
