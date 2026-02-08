import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/feed_service.dart';
import '../../models/comment_model.dart';

class CommentsScreen extends StatefulWidget {
  final String feedId;

  const CommentsScreen({super.key, required this.feedId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FeedService _feedService = FeedService();
  CommentModel? _replyingToComment;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final parentId = _replyingToComment?.id;

    _commentController.clear();
    setState(() {
      _replyingToComment = null;
    });

    await _feedService.addComment(
      widget.feedId,
      user.uid,
      user.displayName ?? 'Anonymous',
      text,
      parentId: parentId,
    );
  }

  Widget _buildCommentItem(CommentModel comment, {int depth = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(comment.text),
          trailing: TextButton(
            child: const Text('Reply'),
            onPressed: () {
              setState(() {
                _replyingToComment = comment;
              });
            },
          ),
        ),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 40.0 * (depth + 1)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: comment.replies.map((reply) => _buildCommentItem(reply, depth: depth + 1)).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _feedService.getComments(widget.feedId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No comments yet.'));
                }

                final comments = snapshot.data!;
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _buildCommentItem(comment);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (_replyingToComment != null)
                  Row(
                    children: [
                      Text("Replying to ${_replyingToComment!.userName}", style: TextStyle(color: Colors.grey[600])),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.cancel, size: 18),
                        onPressed: () {
                          setState(() {
                            _replyingToComment = null;
                          });
                        },
                      )
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: _replyingToComment == null
                              ? 'Add a comment...'
                              : 'Add a reply...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _postComment,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}