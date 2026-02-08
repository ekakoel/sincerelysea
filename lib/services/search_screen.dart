import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/post/post_detail_screen.dart';
import '../screens/profile/profile_screen.dart';

enum SearchType { hashtag, user, location }

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final SearchType? initialType;

  const SearchScreen({super.key, this.initialQuery, this.initialType});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _posts = [];
  List<Map<String, dynamic>> _userResults = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  SearchType _searchType = SearchType.hashtag;
  List<String> _recentSearches = [];
  List<String> _trendingHashtags = [];
  bool _isLoadingTrending = false;
  bool _isMapView = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _searchType = widget.initialType!;
    }
    _loadRecentSearches();
    _fetchTrendingHashtags();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentSearches = prefs.getStringList('recentSearches') ?? [];
      });
    }
  }

  Future<void> _addRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentSearches.remove(query);
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 10) {
          _recentSearches = _recentSearches.sublist(0, 10);
        }
      });
    }
    await prefs.setStringList('recentSearches', _recentSearches);
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentSearches.remove(query);
      });
    }
    await prefs.setStringList('recentSearches', _recentSearches);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentSearches.clear();
      });
    }
    await prefs.remove('recentSearches');
  }

  Future<void> _fetchTrendingHashtags() async {
    if (mounted) setState(() => _isLoadingTrending = true);
    try {
      // Assumes a 'hashtags' collection with 'tag' and 'count' fields
      final snapshot = await FirebaseFirestore.instance
          .collection('hashtags')
          .orderBy('count', descending: true)
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          _trendingHashtags = snapshot.docs.map((doc) {
            final data = doc.data();
            // Use 'tag' field or fallback to document ID if it looks like a tag
            return (data['tag'] as String?) ?? '#${doc.id}';
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching trending hashtags: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    _addRecentSearch(query.trim());

    setState(() {
      _isLoading = true;
      _posts = [];
      _userResults = [];
      _hasMore = true;
    });

    try {
      if (_searchType == SearchType.hashtag) {
        final results = await _searchPostsByHashtag(query.trim());
        setState(() {
          _posts = results;
          if (results.length < 15) _hasMore = false;
        });
      } else if (_searchType == SearchType.location) {
        final results = await _searchPostsByLocation(query.trim());
        setState(() {
          _posts = results;
          if (results.length < 15) _hasMore = false;
        });
      } else {
        final results = await _searchUsers(query.trim());
        setState(() {
          _userResults = results;
          _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_posts.isEmpty || _searchType == SearchType.user) return;

    setState(() => _isLoadingMore = true);

    try {
      List<DocumentSnapshot> results;
      if (_searchType == SearchType.hashtag) {
        results = await _searchPostsByHashtag(
          _searchController.text.trim(),
          startAfter: _posts.last,
        );
      } else {
        results = await _searchPostsByLocation(
          _searchController.text.trim(),
          startAfter: _posts.last,
        );
      }
      setState(() {
        _posts.addAll(results);
        if (results.length < 15) _hasMore = false;
      });
    } catch (e) {
      // Handle error silently or show toast
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<List<DocumentSnapshot>> _searchPostsByHashtag(String query, {DocumentSnapshot? startAfter}) async {
    final tag = query.startsWith('#') ? query : '#$query';
    Query q = FirebaseFirestore.instance
        .collection('feeds')
        .where('hashtags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .limit(15);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snapshot = await q.get();
    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> _searchPostsByLocation(String query, {DocumentSnapshot? startAfter}) async {
    Query q = FirebaseFirestore.instance
        .collection('feeds')
        .where('locationName', isGreaterThanOrEqualTo: query)
        .where('locationName', isLessThan: '$query\uf8ff')
        .orderBy('locationName')
        .limit(15);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snapshot = await q.get();
    return snapshot.docs;
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: _searchType == SearchType.hashtag
                ? 'Search hashtags...'
                : _searchType == SearchType.user
                    ? 'Search users...'
                    : 'Search locations...',
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.grey),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          ),
          if (_searchType == SearchType.location)
            IconButton(
              icon: Icon(_isMapView ? Icons.grid_view : Icons.map),
              onPressed: () {
                setState(() => _isMapView = !_isMapView);
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (_searchType != SearchType.hashtag) {
                      setState(() => _searchType = SearchType.hashtag);
                      _performSearch(_searchController.text);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _searchType == SearchType.hashtag ? Colors.blue : Colors.grey,
                  ),
                  child: const Text('Hashtags'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (_searchType != SearchType.user) {
                      setState(() => _searchType = SearchType.user);
                      _performSearch(_searchController.text);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _searchType == SearchType.user ? Colors.blue : Colors.grey,
                  ),
                  child: const Text('Users'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (_searchType != SearchType.location) {
                      setState(() => _searchType = SearchType.location);
                      _performSearch(_searchController.text);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _searchType == SearchType.location ? Colors.blue : Colors.grey,
                  ),
                  child: const Text('Location'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _searchController.text.isEmpty
          ? _buildPreSearchContent()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchType != SearchType.user
              ? (_posts.isEmpty
                  ? const Center(child: Text('No posts found'))
                  : _isMapView && _searchType == SearchType.location
                      ? _buildMapView()
                      : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = _posts[index].data() as Map<String, dynamic>;
                            final postId = _posts[index].id;
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
                              child: CachedNetworkImage(
                                imageUrl: post['imageUrl'] as String,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[300]),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              ),
                            );
                          },
                          childCount: _posts.length,
                        ),
                      ),
                    ),
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ))
              : (_userResults.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: _userResults.length,
                      itemBuilder: (context, index) {
                        final user = _userResults[index];
                        final photoUrl = user['photoUrl'] ?? user['imageUrl'];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photoUrl != null
                                ? CachedNetworkImageProvider(photoUrl as String)
                                : null,
                            child: photoUrl == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(user['username'] ?? user['displayName'] ?? 'Unknown'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: (user['uid'] ?? user['id']) as String?),
                              ),
                            );
                          },
                        );
                      },
                    )),
    );
  }

  Widget _buildPreSearchContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  GestureDetector(
                    onTap: _clearRecentSearches,
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentSearches.length,
              itemBuilder: (context, index) {
                final query = _recentSearches[index];
                final isTag = query.startsWith('#');
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    child: Icon(
                      isTag ? Icons.tag : Icons.search,
                      color: Colors.black87,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    query,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => _removeRecentSearch(query),
                    splashRadius: 20,
                  ),
                  onTap: () {
                    _searchController.text = query;
                    _performSearch(query);
                  },
                );
              },
            ),
            const Divider(height: 32),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Trending Hashtags',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (_isLoadingTrending)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_trendingHashtags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('No trending hashtags available', style: TextStyle(color: Colors.grey)),
            )
          else
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _trendingHashtags.map((tag) {
                return ActionChip(
                  label: Text(tag),
                  avatar: const Icon(Icons.trending_up, size: 16, color: Colors.blue),
                  backgroundColor: Colors.grey[100],
                  side: BorderSide.none,
                  onPressed: () {
                    _searchController.text = tag;
                    setState(() => _searchType = SearchType.hashtag);
                    _performSearch(tag);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    final Set<Marker> markers = {};
    LatLng? initialPosition;

    for (var postDoc in _posts) {
      final post = postDoc.data() as Map<String, dynamic>;
      final double? lat = post['latitude'];
      final double? lng = post['longitude'];

      if (lat != null && lng != null) {
        initialPosition ??= LatLng(lat, lng);
        markers.add(
          Marker(
            markerId: MarkerId(postDoc.id),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: post['locationName'] ?? 'Post',
              snippet: post['caption'],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(
                      postData: post,
                      postId: postDoc.id,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition ?? const LatLng(0, 0),
        zoom: 10,
      ),
      markers: markers,
    );
  }
}