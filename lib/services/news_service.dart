import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models.dart';

/// Pulls football headlines from a set of well-known RSS feeds and merges
/// them into a single, date-sorted stream.
class NewsService {
  static const List<({String name, String url})> feeds = [
    (name: 'BBC Sport', url: 'https://feeds.bbci.co.uk/sport/football/rss.xml'),
    (name: 'Sky Sports', url: 'https://www.skysports.com/rss/12040'),
    (name: 'ESPN', url: 'https://www.espn.com/espn/rss/soccer/news'),
    (name: 'The Guardian', url: 'https://www.theguardian.com/football/rss'),
  ];

  /// Fetches every feed in parallel. Individual feed failures are ignored
  /// so one bad source can't blank the whole tab.
  static Future<List<NewsItem>> fetchAll() async {
    final results = await Future.wait(
      feeds.map((f) => _fetchOne(f.name, f.url).catchError((_) => <NewsItem>[])),
    );
    final items = results.expand((e) => e).toList();
    items.sort((a, b) {
      final ad = a.published, bd = b.published;
      if (ad == null || bd == null) return 0;
      return bd.compareTo(ad);
    });
    return items;
  }

  static Future<List<NewsItem>> _fetchOne(String source, String url) async {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final doc = XmlDocument.parse(res.body);

    return doc.findAllElements('item').map((item) {
      String text(String tag) =>
          item.getElement(tag)?.innerText.trim() ?? '';

      // Cover image can live in several optional tags depending on the feed.
      String image = '';
      final media = item.getElement('media:thumbnail') ??
          item.getElement('media:content');
      if (media != null) image = media.getAttribute('url') ?? '';
      if (image.isEmpty) {
        image = item.getElement('enclosure')?.getAttribute('url') ?? '';
      }

      return NewsItem(
        title: _clean(text('title')),
        link: text('link'),
        source: source,
        summary: _stripHtml(text('description')),
        imageUrl: image,
        published: _parseDate(text('pubDate')),
      );
    }).where((n) => n.title.isNotEmpty && n.link.isNotEmpty).toList();
  }

  static String _clean(String s) =>
      s.replaceAll('<![CDATA[', '').replaceAll(']]>', '').trim();

  static String _stripHtml(String s) {
    final noTags = _clean(s).replaceAll(RegExp(r'<[^>]*>'), ' ');
    return noTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// RSS dates are RFC-822 (e.g. "Tue, 23 Jun 2026 18:30:00 GMT").
  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final m = RegExp(r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2})')
        .firstMatch(s);
    if (m == null) return DateTime.tryParse(s);
    final month = months[m.group(2)] ?? 1;
    return DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    ).toLocal();
  }
}
