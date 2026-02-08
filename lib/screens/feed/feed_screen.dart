import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../services/feed_service.dart';
import '../../widgets/feed_card.dart';
import '../../models/feed_model.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  late Stream<List<FeedModel>> _feedStream;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _feedStream = _feedService.getFeeds();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _feedStream = _feedService.getFeeds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo-sincerelysea.png', height: 40),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<FeedModel>>(
        stream: _feedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: LayoutBuilder(builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(child: Text('No feeds yet.')),
                  ),
                );
              }),
            );
          }

          final feeds = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _isGridView
                ? MasonryGridView.count(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemCount: feeds.length,
                    itemBuilder: (context, index) {
                      return FeedCard(feed: feeds[index]);
                    },
                  )
                : ListView.builder(
                    itemCount: feeds.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: FeedCard(feed: feeds[index]),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
