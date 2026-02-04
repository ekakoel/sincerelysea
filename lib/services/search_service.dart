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
}