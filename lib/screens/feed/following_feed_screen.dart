import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../post/post_detail_screen.dart';

class FollowingFeedScreen extends StatelessWidget {
  const FollowingFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Following Feed')),
      body: StreamBuilder<List<String>>(
        stream: PostService().getFollowingUids(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final followingUids = snapshot.data ?? [];

          if (followingUids.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Follow people to see their posts here!'),
                ],
              ),
            );
          }

          // Firestore 'whereIn' limit is 10 (safe limit).
          // We take the last 10 followed users.
          final limitedUids = followingUids.length > 10 
              ? followingUids.sublist(followingUids.length - 10) 
              : followingUids;

          return StreamBuilder<QuerySnapshot>(
            stream: PostService().getPostsFromFollowedUsers(limitedUids),
            builder: (context, postSnapshot) {
              if (postSnapshot.hasError) {
                return Center(child: Text('Error: ${postSnapshot.error}'));
              }
              if (postSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = postSnapshot.data?.docs ?? [];

              if (posts.isEmpty) {
                return const Center(child: Text('No posts from followed users yet.'));
              }

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index].data() as Map<String, dynamic>;
                  final postId = posts[index].id;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              postData: post,
                              postId: postId,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(post['userName'] ?? 'Unknown'),
                            subtitle: Text(
                              (post['createdAt'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          CachedNetworkImage(
                            imageUrl: post['imageUrl'],
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 300,
                              color: Colors.grey[300],
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              post['caption'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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