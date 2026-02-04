import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/feed_service.dart';
import '../models/feed_model.dart';
import '../widgets/feed_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FeedService _feedService = FeedService();
  late Stream<List<FeedModel>> _feedStream;

  @override
  void initState() {
    super.initState();
    _feedStream = _feedService.getFeeds();
  }

  Future<void> _handleRefresh() async {
    // await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _feedStream = _feedService.getFeeds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<FeedModel>>(
        stream: _feedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: const Center(child: Text('No feeds yet.')),
            );
          }

          final feeds = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: MasonryGridView.count(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: feeds.length,
              itemBuilder: (context, index) {
                return FeedCard(feed: feeds[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
