import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../services/feed_service.dart';
import '../../models/feed_model.dart';
import '../../widgets/feed_card.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    final feedService = FeedService();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Posts')),
      body: StreamBuilder<List<FeedModel>>(
        stream: feedService.getSavedFeeds(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No saved posts yet.'));
          }

          final feeds = snapshot.data!;

          return MasonryGridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: feeds.length,
            itemBuilder: (context, index) {
              return FeedCard(feed: feeds[index]);
            },
          );
        },
      ),
    );
  }
}