import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/post_service.dart';
import '../../widgets/hashtag_text.dart';
import '../../services/search_screen.dart';
import '../profile/likes_list_screen.dart';
import 'comment_likes_list_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const PostDetailScreen({
    super.key,
    required this.postData,
    required this.postId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late bool isLiked;
  late int likeCount;
  late bool isSaved;
  late bool isWishlisted;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyParentId;
  String? _replyToUserName;

  @override
  void initState() {
    super.initState();
    final List likes = widget.postData['likes'] ?? [];
    isLiked = likes.contains(currentUserId);
    likeCount = likes.length;

    final List savedBy = widget.postData['savedBy'] ?? [];
    isSaved = savedBy.contains(currentUserId);

    final List wishlistedBy = widget.postData['wishlistedBy'] ?? [];
    isWishlisted = wishlistedBy.contains(currentUserId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      await PostService().toggleLike(
        widget.postId,
        currentUserId,
        widget.postData['uid'] ?? '',
        widget.postData['likes'] ?? [],
      );
      
      // Update local data reference to keep consistency if toggled again
      final List likes = widget.postData['likes'] ?? [];
      if (isLiked) {
        if (!likes.contains(currentUserId)) likes.add(currentUserId);
      } else {
        likes.remove(currentUserId);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          isLiked = !isLiked;
          likeCount += isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error liking post: $e')),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    setState(() {
      isSaved = !isSaved;
    });

    try {
      await PostService().toggleSave(
        widget.postId,
        currentUserId,
        widget.postData['savedBy'] ?? [],
      );

      // Update local data reference
      final List savedBy = widget.postData['savedBy'] ?? [];
      if (isSaved) {
        if (!savedBy.contains(currentUserId)) savedBy.add(currentUserId);
      } else {
        savedBy.remove(currentUserId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSaved = !isSaved;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving post: $e')),
        );
      }
    }
  }

  Future<void> _toggleWishlist() async {
    setState(() {
      isWishlisted = !isWishlisted;
    });

    try {
      await PostService().toggleWishlist(
        widget.postId,
        currentUserId,
        widget.postData['wishlistedBy'] ?? [],
      );

      // Update local data reference
      final List wishlistedBy = widget.postData['wishlistedBy'] ?? [];
      if (isWishlisted) {
        if (!wishlistedBy.contains(currentUserId)) wishlistedBy.add(currentUserId);
      } else {
        wishlistedBy.remove(currentUserId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isWishlisted = !isWishlisted;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating wishlist: $e')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await PostService().addComment(
        widget.postId,
        user.uid,
        user.displayName ?? 'Anonymous',
        _commentController.text.trim(),
        parentId: _replyParentId,
      );
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() {
          _replyParentId = null;
          _replyToUserName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    }
  }

  Future<void> _sharePost() async {
    final String caption = widget.postData['caption'] ?? '';
    final String imageUrl = widget.postData['imageUrl'];

    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      await Share.shareXFiles([XFile(file.path)], text: caption);
    } catch (e) {
      // Fallback to sharing text if image download fails
      await Share.share('$caption\n$imageUrl');
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await PostService().deletePost(
          widget.postId,
          widget.postData['imageUrl'] ?? '',
        );
        if (mounted) {
          Navigator.pop(context); // Go back to feed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    }
  }

  Future<void> _editPost() async {
    final TextEditingController editController = TextEditingController(
      text: widget.postData['caption'],
    );

    final newCaption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Caption'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter new caption',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newCaption != null && newCaption != widget.postData['caption']) {
      try {
        await PostService().updatePostCaption(widget.postId, newCaption);
        setState(() {
          widget.postData['caption'] = newCaption;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caption updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating caption: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          if (widget.postData['uid'] == currentUserId)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editPost();
                } else if (value == 'delete') {
                  _confirmDelete();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Edit')]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')]),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(widget.postData['userName'] ?? 'Unknown'),
                    subtitle: widget.postData['locationName'] != null
                        ? GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SearchScreen(
                                    initialQuery: widget.postData['locationName'] as String,
                                    initialType: SearchType.location,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              widget.postData['locationName'] as String,
                              style: const TextStyle(color: Colors.blue),
                            ),
                          )
                        : null,
                  ),
                  CachedNetworkImage(
                    imageUrl: widget.postData['imageUrl'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : null,
                          ),
                          onPressed: _toggleLike,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LikesListScreen(
                                  likeUids: widget.postData['likes'] ?? [],
                                ),
                              ),
                            );
                          },
                          child: Text('$likeCount likes', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: _sharePost,
                        ),
                        IconButton(
                          icon: Icon(
                            isWishlisted ? Icons.star : Icons.star_border,
                            color: isWishlisted ? Colors.amber : null,
                          ),
                          onPressed: _toggleWishlist,
                        ),
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                          ),
                          onPressed: _toggleSave,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: HashtagText(
                      text: widget.postData['caption'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: PostService().getComments(widget.postId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No comments yet. Be the first to comment!'),
                        );
                      }

                      // Group comments: Roots and Replies
                      final Map<String, List<Map<String, dynamic>>> repliesMap = {};
                      final List<Map<String, dynamic>> rootComments = [];

                      for (var doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id;
                        if (data['parentId'] != null) {
                          if (repliesMap[data['parentId']] == null) {
                            repliesMap[data['parentId']] = [];
                          }
                          repliesMap[data['parentId']]!.add(data);
                        } else {
                          rootComments.add(data);
                        }
                      }

                      // Flatten list for display
                      final List<Map<String, dynamic>> displayList = [];
                      for (var root in rootComments) {
                        displayList.add({...root, 'isReply': false});
                        if (repliesMap.containsKey(root['id'])) {
                          final replies = repliesMap[root['id']]!;
                          // Sort replies oldest to newest (chronological)
                          replies.sort((a, b) {
                            final tA = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                            final tB = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                            return tA.compareTo(tB);
                          });
                          for (var reply in replies) {
                            displayList.add({...reply, 'isReply': true});
                          }
                        }
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final comment = displayList[index];
                          return _CommentTile(
                            comment: comment,
                            postId: widget.postId,
                            currentUserId: currentUserId,
                            postOwnerUid: widget.postData['uid'] ?? '',
                            isReply: comment['isReply'] ?? false,
                            onReply: () {
                              setState(() {
                                _replyParentId = (comment['isReply'] ?? false) ? comment['parentId'] : comment['id'];
                                _replyToUserName = comment['userName'];
                              });
                              _commentFocusNode.requestFocus();
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyToUserName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Replying to $_replyToUserName',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _replyParentId = null;
                                    _replyToUserName = null;
                                  }),
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          decoration: InputDecoration(
                            hintText: _replyToUserName != null ? 'Reply to $_replyToUserName...' : 'Add a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _postComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> comment;
  final String postId;
  final String currentUserId;
  final String postOwnerUid;
  final bool isReply;
  final VoidCallback onReply;

  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.currentUserId,
    required this.postOwnerUid,
    this.isReply = false,
    required this.onReply,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool isLiked;
  late int likeCount;

  @override
  void initState() {
    super.initState();
    _initLikes();
  }

  @override
  void didUpdateWidget(covariant _CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment != widget.comment) {
      _initLikes();
    }
  }

  void _initLikes() {
    final List likes = widget.comment['likes'] ?? [];
    isLiked = likes.contains(widget.currentUserId);
    likeCount = likes.length;
  }

  Future<void> _toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      await PostService().toggleCommentLike(
        widget.postId,
        widget.comment['id'],
        widget.currentUserId,
        widget.comment['likes'] ?? [],
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isLiked = !isLiked;
          likeCount += isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error liking comment: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await PostService().deleteComment(widget.postId, widget.comment['id']);
        // No need to show snackbar here as the stream will update the UI automatically
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting comment: $e')),
          );
        }
      }
    }
  }

  Future<void> _editComment() async {
    final TextEditingController editController = TextEditingController(
      text: widget.comment['text'],
    );

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty && newText != widget.comment['text']) {
      try {
        await PostService().updateComment(
          widget.postId,
          widget.comment['id'],
          newText,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating comment: $e')),
          );
        }
      }
    }
  }

  void _showOptions() {
    final bool isOwner = widget.currentUserId == widget.comment['uid'];
    final bool isPostOwner = widget.currentUserId == widget.postOwnerUid;

    if (!isOwner && !isPostOwner) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _editComment();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Comment', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Timestamp? timestamp = widget.comment['createdAt'];
    final String timeAgo = timestamp != null ? _formatTimeAgo(timestamp.toDate()) : '';
    final bool isEdited = widget.comment['isEdited'] ?? false;

    return Padding(
      padding: EdgeInsets.only(left: widget.isReply ? 40.0 : 0),
      child: ListTile(
        onLongPress: (widget.currentUserId == widget.comment['uid'] || widget.currentUserId == widget.postOwnerUid)
            ? _showOptions
            : null,
        leading: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 20)),
        title: Row(
          children: [
            Text(widget.comment['userName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Text(timeAgo, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            if (isEdited) ...[
              const SizedBox(width: 4),
              Text('(edited)', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.comment['text'] ?? '', style: const TextStyle(fontSize: 14)),
            if (likeCount > 0) ...[
              const SizedBox(height: 8),
              _buildLikersRow(),
            ]
          ],
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: isLiked ? Colors.red : Colors.grey,
              ),
              onPressed: _toggleLike,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
            if (likeCount > 0) ...[
              const SizedBox(width: 4),
              Text('$likeCount', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.reply, size: 18, color: Colors.grey),
              onPressed: widget.onReply,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikersRow() {
    final List<dynamic> likerUids = widget.comment['likes'] ?? [];
    const double avatarSize = 22;
    final int displayCount = likerUids.length > 3 ? 3 : likerUids.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommentLikesListScreen(likeUids: likerUids),
          ),
        );
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            SizedBox(
              height: avatarSize,
              width: avatarSize + (displayCount > 0 ? (displayCount - 1) * (avatarSize * 0.7) : 0),
              child: Stack(
                children: List.generate(displayCount, (index) {
                  final uid = likerUids[index];
                  return Positioned(
                    left: index * (avatarSize * 0.7),
                    child: _buildMiniAvatar(uid),
                  );
                }),
              ),
            ),
            if (likerUids.length > displayCount) ...[
              const SizedBox(width: 6),
              Text(
                '+${likerUids.length - displayCount}',
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatar(String uid) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
      ),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          String? photoUrl;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            photoUrl = data['photoUrl'] ?? data['imageUrl'];
          }
          return CircleAvatar(
            radius: 11,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 12) : null,
          );
        },
      ),
    );
  }
}