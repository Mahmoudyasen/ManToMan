import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/news_service.dart';
import '../theme.dart';

/// Aggregated football news from BBC, Sky Sports, ESPN and The Guardian.
class NewsScreen extends StatefulWidget {
  final VoidCallback onMenu;
  const NewsScreen({super.key, required this.onMenu});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  Future<List<NewsItem>>? _future;
  String _source = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = NewsService.fetchAll();
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ['All', ...NewsService.feeds.map((f) => f.name)];
    return Column(
      children: [
        ScreenHeader(
          title: 'Football News',
          subtitle: 'TOP SOURCES, ONE FEED',
          onMenu: widget.onMenu,
          trailing: GestureDetector(
            onTap: _load,
            child: Container(
              width: 46,
              height: 46,
              decoration:
                  const BoxDecoration(color: C.chip, shape: BoxShape.circle),
              child: const Icon(Icons.refresh_rounded, color: C.ink, size: 22),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              for (final s in sources)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _source = s),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: _source == s ? C.cardGradient : null,
                        color: _source == s ? null : C.chip,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _source == s ? Colors.white : C.ink)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: FutureBuilder<List<NewsItem>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: C.violetMid));
              }
              final all = snap.data ?? [];
              final items = _source == 'All'
                  ? all
                  : all.where((n) => n.source == _source).toList();
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'No headlines',
                  message:
                      'Couldn\'t reach the feeds. Check your connection and refresh.',
                  action: GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                          color: C.chip,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Text('Retry',
                          style: TextStyle(
                              color: C.violetMid,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                color: C.violetMid,
                onRefresh: () async => _load(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  itemCount: items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _newsCard(items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _newsCard(NewsItem n) {
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => _open(n.link),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.imageUrl.isNotEmpty)
              Image.network(
                n.imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TagBadge(n.source.toUpperCase()),
                      const Spacer(),
                      if (n.published != null)
                        Text(DateFormat('d MMM · HH:mm').format(n.published!),
                            style:
                                const TextStyle(fontSize: 11.5, color: C.muted)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(n.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: C.ink)),
                  if (n.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(n.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, height: 1.4, color: C.muted)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Text('Read full story',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.violetMid)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 16, color: C.violetMid),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
