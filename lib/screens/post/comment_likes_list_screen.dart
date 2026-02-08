import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';

class CommentLikesListScreen extends StatelessWidget {
  final List<dynamic> likeUids;

  const CommentLikesListScreen({super.key, required this.likeUids});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Likes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: likeUids.isEmpty
          ? const Center(child: Text('No likes on this comment yet'))
          : ListView.builder(
              itemCount: likeUids.length,
              itemBuilder: (context, index) {
                final uid = likeUids[index] as String;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.grey),
                        title: Text('Loading...'),
                      );
                    }

                    if (!snapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final userName = data['displayName'] ?? data['userName'] ?? 'User';
                    final photoUrl = data['photoUrl'] ?? data['imageUrl'];
                    final bio = data['bio'] ?? '';

                    return ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: uid),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                          child: photoUrl == null ? const Icon(Icons.person) : null,
                        ),
                      ),
                      title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: bio.isNotEmpty 
                          ? Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis) 
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: uid),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}