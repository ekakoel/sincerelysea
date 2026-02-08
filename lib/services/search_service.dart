import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    // Perform a prefix search on the 'displayName' field.
    // Note: Firestore queries are case-sensitive by default.
    final snapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<DocumentSnapshot>> searchPostsByHashtag(
    String hashtag, {
    int limit = 15,
    DocumentSnapshot? startAfter,
  }) async {
    if (hashtag.isEmpty) return [];

    final queryTag = hashtag.startsWith('#') ? hashtag : '#$hashtag';

    Query query = _firestore
        .collection('feeds')
        .where('hashtags', arrayContains: queryTag);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> searchPostsByLocation(
    String locationName, {
    int limit = 15,
    DocumentSnapshot? startAfter,
  }) async {
    if (locationName.isEmpty) return [];

    Query query = _firestore
        .collection('feeds')
        .where('locationName', isGreaterThanOrEqualTo: locationName)
        .where('locationName', isLessThan: '$locationName\uf8ff');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs;
  }
}