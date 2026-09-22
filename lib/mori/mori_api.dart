import 'dart:convert';
import 'package:http/http.dart' as http;

// Mori-style client-side resolvers (open engines, no server needed).
// TikTok via TikWM public API (no watermark, direct play URL).
// Other platforms fall back to Railway yt-dlp universal endpoint.
class MoriApi {
  static const String _ua =
      'Mozilla/5.0 (Linux; Android 13; RMX2189) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static Map<String, String> headersFor(String platform) {
    switch (platform) {
      case 'tiktok':
        return {'User-Agent': _ua, 'Referer': 'https://www.tiktok.com/'};
      case 'instagram':
        return {'User-Agent': _ua, 'Referer': 'https://www.instagram.com/'};
      case 'facebook':
        return {'User-Agent': _ua, 'Referer': 'https://www.facebook.com/'};
      case 'twitter':
        return {'User-Agent': _ua, 'Referer': 'https://x.com/'};
      case 'pinterest':
        return {'User-Agent': _ua, 'Referer': 'https://www.pinterest.com/'};
      case 'bilibili':
        return {'User-Agent': _ua, 'Referer': 'https://www.bilibili.com/'};
      case 'pixiv':
        return {'User-Agent': _ua, 'Referer': 'https://www.pixiv.net/'};
      case 'youtube':
        return {'User-Agent': _ua, 'Referer': 'https://www.youtube.com/'};
      default:
        return {'User-Agent': _ua};
    }
  }

  static String detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('tiktok.com') || u.contains('vt.tiktok') || u.contains('vm.tiktok')) return 'tiktok';
    if (u.contains('instagram.com')) return 'instagram';
    if (u.contains('youtube.com') || u.contains('youtu.be')) return 'youtube';
    if (u.contains('twitter.com') || u.contains('x.com')) return 'twitter';
    if (u.contains('facebook.com') || u.contains('fb.watch') || u.contains('fb.com')) return 'facebook';
    if (u.contains('pinterest.com') || u.contains('pin.it')) return 'pinterest';
    if (u.contains('threads.com') || u.contains('threads.net')) return 'threads';
    if (u.contains('spotify')) return 'spotify';
    if (u.contains('music.apple.com')) return 'applemusic';
    if (u.contains('bilibili') || u.contains('b23.tv') || u.contains('bili.im')) return 'bilibili';
    if (u.contains('douyin')) return 'douyin';
    if (u.contains('xiaohongshu') || u.contains('xhslink')) return 'rednote';
    if (u.contains('pixiv.net')) return 'pixiv';
    if (u.contains('bandcamp.com')) return 'bandcamp';
    return 'universal';
  }

  /// Resolve TikTok via TikWM (no watermark). Returns siputzx-compatible
  /// {status, data:{urls, metadata}} or throws.
  static Future<Map<String, dynamic>> resolveTiktok(String url) async {
    final apiUrl = Uri.parse("https://www.tikwm.com/api/?url=${Uri.encodeComponent(url)}");
    final res = await http.get(apiUrl, headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception('TikWM HTTP ${res.statusCode}');
    final json = jsonDecode(res.body);
    if (json['code'] != 0 || json['data'] == null) {
      throw Exception((json['msg'] ?? 'TikWM gagal').toString());
    }
    final data = json['data'] as Map<String, dynamic>;
    final play = (data['play'] ?? '').toString();
    if (play.isEmpty) throw Exception('TikWM tidak mengembalikan video.');
    final author = data['author'] is Map ? (data['author']['nickname'] ?? 'Unknown').toString() : 'Unknown';
    // TikTok slide photos: images array
    final List<String> urls = [play];
    if (data['images'] is List && (data['images'] as List).isNotEmpty) {
      urls.clear();
      for (final img in (data['images'] as List)) {
        if (img != null && img.toString().isNotEmpty) urls.add(img.toString());
      }
    }
    return {
      'status': true,
      'platform': 'tiktok',
      'data': {
        'urls': urls,
        'metadata': {
          'title': (data['title'] ?? 'TikTok Video').toString(),
          'creator': author,
          'author': author,
          'thumbnail': (data['cover'] ?? data['origin_cover'] ?? '').toString(),
          'music': (data['music'] ?? '').toString(),
        },
      },
    };
  }
}
