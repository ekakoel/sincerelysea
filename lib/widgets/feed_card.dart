import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/feed_model.dart';
import '../services/feed_service.dart';
import '../screens/feed/comments_screen.dart';

class FeedCard extends StatelessWidget {
  final FeedModel feed;

  const FeedCard({super.key, required this.feed});

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _deletePost(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FeedService().deleteFeed(feed.id, feed.imageUrl);
    }
  }

  Future<void> _sharePost() async {
    try {
      // Download the image to a temporary file
      final file = await DefaultCacheManager().getSingleFile(feed.imageUrl);
      // Share the image file and the caption
      await Share.shareXFiles([XFile(file.path)], text: feed.caption);
    } catch (e) {
      // Fallback: Share just the text and URL if image download fails
      await Share.share('${feed.caption}\n\n${feed.imageUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLiked = user != null && feed.likes.contains(user.uid);
    final isSaved = user != null && feed.savedBy.contains(user.uid);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.grey.shade200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: feed.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(color: Colors.white),
                ),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                feed.caption,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    feed.userName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _timeAgo(feed.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (user != null) {
                        FeedService().toggleLike(feed.id, user.uid, isLiked);
                      }
                    },
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.black54,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${feed.likes.length}'),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommentsScreen(feedId: feed.id),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 22,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text('${feed.commentCount}'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _sharePost,
                    child: const Icon(
                      Icons.share_outlined,
                      size: 22,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (user != null) {
                        FeedService().toggleSave(feed.id, user.uid, isSaved);
                      }
                    },
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 24,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (user != null && user.uid == feed.uid) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => _deletePost(context),
                child: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
