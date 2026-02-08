import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../post/post_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUpdatingFollow = false;
  late Stream<int> _followerCountStream;
  late Stream<int> _followingCountStream;
  late Stream<QuerySnapshot> _postsStream;
  late Stream<QuerySnapshot> _savedPostsStream;
  late Stream<QuerySnapshot> _wishlistPostsStream;
  late String _targetUid;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _targetUid = widget.userId ?? currentUser?.uid ?? '';
    
    if (_targetUid == currentUser?.uid) {
      // Reload user data to get the latest emailVerified status
      currentUser?.reload().then((_) {
        if (mounted) setState(() {});
      });
    }

    if (_targetUid.isNotEmpty) {
      _followerCountStream = PostService().getFollowerCount(_targetUid);
      _followingCountStream = PostService().getFollowingCount(_targetUid);
      _postsStream = PostService().getUserPosts(_targetUid);
      _savedPostsStream = FirebaseFirestore.instance
          .collection('feeds')
          .where('savedBy', arrayContains: _targetUid)
          .orderBy('createdAt', descending: true)
          .snapshots();
      _wishlistPostsStream = FirebaseFirestore.instance
          .collection('feeds')
          .where('wishlistedBy', arrayContains: _targetUid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // Handle empty UID case safely with empty streams if needed
      _followerCountStream = Stream.value(0);
      _followingCountStream = Stream.value(0);
      _postsStream = const Stream.empty();
      _savedPostsStream = const Stream.empty();
      _wishlistPostsStream = const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Gunakan _targetUid yang diinisialisasi di initState atau logic yang konsisten
    // Namun karena widget.userId bisa berubah jika parent rebuild, 
    // idealnya kita update di didUpdateWidget, tapi untuk simpelnya kita pakai _targetUid
    // Asumsi ProfileScreen di-push dengan userId yang tetap.

    if (_targetUid.isEmpty) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            if (widget.userId == null || widget.userId == currentUid)
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  // Note: You might want to navigate to a login screen here
                },
              ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(_targetUid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
               return const Center(child: CircularProgressIndicator());
            }
            
            String userName = 'User';
            String? photoUrl;
            String bio = '';
            
            // Try to get data from Firestore 'users' collection
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              userName = data['displayName'] ?? data['userName'] ?? 'User';
              photoUrl = data['photoUrl'] ?? data['imageUrl'];
              bio = data['bio'] ?? '';
            } else if (_targetUid == currentUid) {
               // Fallback to Auth data if it's the current user and Firestore doc doesn't exist
               final user = FirebaseAuth.instance.currentUser;
               userName = user?.displayName ?? 'User';
               photoUrl = user?.photoURL;
            }

            return Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    if (photoUrl != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            appBar: AppBar(
                              backgroundColor: Colors.black,
                              iconTheme: const IconThemeData(color: Colors.white),
                            ),
                            body: Center(
                              child: InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                    child: photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (_targetUid == currentUid) ...[
                      const SizedBox(width: 8),
                      if (FirebaseAuth.instance.currentUser?.emailVerified ?? false)
                        const Icon(Icons.verified, color: Colors.blue, size: 20)
                      else
                        Tooltip(
                          message: 'Email not verified. Tap to resend.',
                          child: InkWell(
                            onTap: () async {
                              try {
                                await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Verification email sent! Please check your inbox.')),
                                  );
                                }
                              } catch (e) {
                                // Ignore or handle error
                              }
                            },
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          ),
                        ),
                    ],
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCountColumn("Followers", _followerCountStream),
                    const SizedBox(width: 24),
                    _buildCountColumn("Following", _followingCountStream),
                  ],
                ),
                if (_targetUid != currentUid) ...[
                  const SizedBox(height: 10),
                  StreamBuilder<bool>(
                    stream: PostService().isFollowing(currentUid, _targetUid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final isFollowing = snapshot.data!;
                      return ElevatedButton(
                        onPressed: _isUpdatingFollow
                            ? null
                            : () async {
                                setState(() => _isUpdatingFollow = true);
                                try {
                                  if (isFollowing) {
                                    await PostService().unfollowUser(currentUid, _targetUid);
                                  } else {
                                    await PostService().followUser(currentUid, _targetUid);
                                  }
                                } finally {
                                  if (mounted) setState(() => _isUpdatingFollow = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey[300] : Colors.blue,
                          foregroundColor: isFollowing ? Colors.black : Colors.white,
                        ),
                        child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                      );
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            uid: currentUid,
                            currentName: userName,
                            currentBio: bio,
                            currentPhotoUrl: photoUrl,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                    child: const Text('Edit Profile'),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const TabBar(
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.black,
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on), text: "Post"),
                    Tab(icon: Icon(Icons.favorite_border), text: "Wishlist"),
                    Tab(icon: Icon(Icons.bookmark_border), text: "Bookmark"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPostGrid(_postsStream),
                      _buildPostGrid(_wishlistPostsStream, isWishlist: true),
                      _buildPostGrid(_savedPostsStream, isBookmark: true),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCountColumn(String label, Stream<int> stream) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        return Column(
          children: [
            Text(
              '${snapshot.data ?? 0}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRemoveFromWishlist(BuildContext context, String postId, Map<String, dynamic> postData) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Wishlist'),
        content: const Text('Are you sure you want to remove this item from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        try {
          await PostService().toggleWishlist(
            postId,
            currentUid,
            postData['wishlistedBy'] ?? [],
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Removed from wishlist')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _confirmRemoveFromBookmark(BuildContext context, String postId, Map<String, dynamic> postData) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Bookmark'),
        content: const Text('Are you sure you want to remove this item from your bookmarks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        try {
          await PostService().toggleSave(
            postId,
            currentUid,
            postData['savedBy'] ?? [],
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Removed from bookmarks')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    }
  }

  Widget _buildPostGrid(Stream<QuerySnapshot> stream, {bool isWishlist = false, bool isBookmark = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, postSnapshot) {
        if (postSnapshot.hasError) {
          return Center(child: Text('Error: ${postSnapshot.error}'));
        }
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = postSnapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            final postId = posts[index].id;

            return GestureDetector(
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
              onLongPress: (_targetUid == FirebaseAuth.instance.currentUser?.uid && (isWishlist || isBookmark))
                  ? () {
                      if (isWishlist) _confirmRemoveFromWishlist(context, postId, post);
                      if (isBookmark) _confirmRemoveFromBookmark(context, postId, post);
                    }
                  : null,
              child: CachedNetworkImage(
                imageUrl: (post['imageUrl'] as String?) ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            );
          },
        );
      },
    );
  }
}