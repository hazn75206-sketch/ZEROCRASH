import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class MoriDownloaderPage extends StatefulWidget {
  const MoriDownloaderPage({super.key});

  @override
  State<MoriDownloaderPage> createState() => _MoriDownloaderPageState();
}

class _MoriDownloaderPageState extends State<MoriDownloaderPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _platform;
  String? _errorMessage;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  final Color bgDark = const Color(0xFF00050B);
  final Color cardDark = const Color(0xFF0A1118);
  final Color primaryPurple = const Color(0xFF102A43);
  final Color accentPurple = const Color(0xFF00E5FF);
  final Color primaryWhite = Colors.white;
  final Color textGrey = const Color(0xFF78909C);

  static const String _apiBase = "https://private-server-production.up.railway.app";

  static const Map<String, Map<String, dynamic>> _platforms = {
    'tiktok': {'name': 'TikTok', 'icon': Icons.music_note},
    'instagram': {'name': 'Instagram', 'icon': Icons.camera_alt},
    'youtube': {'name': 'YouTube', 'icon': Icons.play_circle_fill},
    'facebook': {'name': 'Facebook', 'icon': Icons.facebook},
    'twitter': {'name': 'Twitter/X', 'icon': Icons.alternate_email},
    'pinterest': {'name': 'Pinterest', 'icon': Icons.push_pin},
    'threads': {'name': 'Threads', 'icon': Icons.forum},
    'bilibili': {'name': 'Bilibili', 'icon': Icons.live_tv},
    'douyin': {'name': 'Douyin', 'icon': Icons.video_library},
    'rednote': {'name': 'RedNote', 'icon': Icons.book},
    'pixiv': {'name': 'Pixiv', 'icon': Icons.brush},
    'bandcamp': {'name': 'Bandcamp', 'icon': Icons.album},
    'spotify': {'name': 'Spotify', 'icon': Icons.headphones},
    'applemusic': {'name': 'Apple Music', 'icon': Icons.library_music},
  };

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

  Map<String, String> _headersFor(String platform) {
    const ua = 'Mozilla/5.0 (Linux; Android 13; RMX2189) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    switch (platform) {
      case 'tiktok':
        return {'User-Agent': ua, 'Referer': 'https://www.tiktok.com/'};
      case 'instagram':
        return {'User-Agent': ua, 'Referer': 'https://www.instagram.com/'};
      case 'facebook':
        return {'User-Agent': ua, 'Referer': 'https://www.facebook.com/'};
      case 'twitter':
        return {'User-Agent': ua, 'Referer': 'https://x.com/'};
      case 'pinterest':
        return {'User-Agent': ua, 'Referer': 'https://www.pinterest.com/'};
      case 'bilibili':
        return {'User-Agent': ua, 'Referer': 'https://www.bilibili.com/'};
      case 'pixiv':
        return {'User-Agent': ua, 'Referer': 'https://www.pixiv.net/'};
      case 'youtube':
        return {'User-Agent': ua, 'Referer': 'https://www.youtube.com/'};
      default:
        return {'User-Agent': ua};
    }
  }

  @override
  void initState() {
    super.initState();
    _pasteFromClipboard();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.startsWith('http') && mounted) {
        setState(() => _urlController.text = text);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    var input = _urlController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = "Tempel link dulu (TikTok, IG, YouTube, FB, X, Pinterest, dll).";
        _result = null;
      });
      return;
    }
    final match = RegExp(r'https?://[^\s]+').firstMatch(input);
    final url = match != null ? match.group(0)! : input;
    final platform = detectPlatform(url);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _platform = platform;
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
    });

    try {
      final apiUrl = Uri.parse("$_apiBase/api/d/universal?url=${Uri.encodeComponent(url)}");
      final response = await http.get(apiUrl).timeout(const Duration(seconds: 90));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == true && json['data'] != null) {
          setState(() => _result = Map<String, dynamic>.from(json['data'] as Map));
          _initPreview();
        } else {
          setState(() => _errorMessage = (json['message'] ?? "Gagal mengambil media.").toString());
        }
      } else {
        setState(() => _errorMessage = "Gagal terhubung ke server.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Terjadi kesalahan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initPreview() {
    final urls = (_result?['urls'] as List?) ?? [];
    if (urls.isEmpty) return;
    final first = urls[0].toString();
    final isPhoto = RegExp(r'\.(jpg|jpeg|png|webp)(\?|$)').hasMatch(first.split('?')[0].toLowerCase());
    if (isPhoto) return;
    final headers = _headersFor(_platform ?? 'universal');
    _videoController = VideoPlayerController.networkUrl(Uri.parse(first), httpHeaders: headers)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
            showControls: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: primaryPurple,
              handleColor: accentPurple,
              backgroundColor: textGrey.withValues(alpha: 0.3),
              bufferedColor: textGrey.withValues(alpha: 0.2),
            ),
          );
        });
      }).catchError((e) {
        if (!mounted) return;
        setState(() => _errorMessage = "Video tidak bisa diputar langsung. Gunakan DOWNLOAD untuk simpan & putar offline.");
      });
  }

  Future<void> _downloadShare() async {
    final urls = (_result?['urls'] as List?) ?? [];
    if (urls.isEmpty) return;
    final headers = _headersFor(_platform ?? 'universal');
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mengunduh...', style: TextStyle(color: primaryWhite)), backgroundColor: primaryPurple),
      );
      final url = urls[0].toString();
      final ext = RegExp(r'\.(jpg|jpeg|png|webp)(\?|$)').hasMatch(url.split('?')[0].toLowerCase()) ? 'jpg' : 'mp4';
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 120));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/mori_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Media dari: ${_result!['metadata']?['creator'] ?? 'Unknown'}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: TextStyle(color: primaryWhite)), backgroundColor: primaryPurple),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plat = _platform != null ? _platforms[_platform] : null;
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text('MORI DOWNLOADER', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: bgDark,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      style: TextStyle(color: primaryWhite, fontSize: 15),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Tempel link apa saja',
                        labelStyle: TextStyle(color: accentPurple),
                        hintText: 'TikTok / IG / YouTube / FB / X / Pinterest...',
                        hintStyle: TextStyle(color: textGrey, fontSize: 13),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryPurple.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accentPurple, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF00050B).withValues(alpha: 0.3),
                        prefixIcon: Icon(Icons.link, color: accentPurple),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.paste, color: accentPurple),
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (plat != null)
                      Row(
                        children: [
                          Icon(plat['icon'] as IconData, color: accentPurple, size: 18),
                          const SizedBox(width: 8),
                          Text('Terdeteksi: ${plat['name']}', style: TextStyle(color: accentPurple, fontSize: 13)),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _resolve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: primaryWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isLoading ? Icons.hourglass_top : Icons.download, size: 20, color: primaryWhite),
                            const SizedBox(width: 8),
                            Text(_isLoading ? 'PROSES...' : 'DOWNLOAD',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _platforms.entries.map((e) {
                  return Chip(
                    label: Text(e.value['name'] as String, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    avatar: Icon(e.value['icon'] as IconData, size: 14, color: accentPurple),
                    backgroundColor: cardDark,
                    side: BorderSide(color: primaryPurple.withValues(alpha: 0.4)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: accentPurple),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_errorMessage!, style: TextStyle(color: accentPurple, fontSize: 13))),
                    ],
                  ),
                ),
              if (_result != null) Expanded(child: _buildResult()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final urls = (_result?['urls'] as List?) ?? [];
    final meta = _result?['metadata'] as Map?;
    final first = urls.isNotEmpty ? urls[0].toString() : '';
    final isPhoto = first.isNotEmpty && RegExp(r'\.(jpg|jpeg|png|webp)(\?|$)').hasMatch(first.split('?')[0].toLowerCase());
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                if (!isPhoto && _chewieController != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: Chewie(controller: _chewieController!),
                    ),
                  )
                else if (!isPhoto)
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00050B).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: _isLoading
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              CircularProgressIndicator(color: accentPurple),
                              const SizedBox(height: 12),
                              Text('Loading video...', style: TextStyle(color: accentPurple, fontSize: 13)),
                            ])
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              CircularProgressIndicator(color: accentPurple),
                              const SizedBox(height: 12),
                              Text('Loading video...', style: TextStyle(color: accentPurple, fontSize: 13)),
                            ]),
                    ),
                  ),
                if (isPhoto)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(first, headers: _headersFor(_platform ?? 'universal'),
                        loadingBuilder: (c, child, p) => p == null ? child : Center(child: CircularProgressIndicator(color: accentPurple)),
                        errorBuilder: (c, e, s) => Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Gambar tidak bisa dimuat. Gunakan DOWNLOAD.', style: TextStyle(color: accentPurple)),
                            )),
                  ),
                const SizedBox(height: 12),
                if (meta != null)
                  Text('${meta['title'] ?? 'No Title'}',
                      style: TextStyle(color: primaryWhite, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Creator: ${meta?['creator'] ?? 'Unknown'} • ${urls.length} media',
                    style: TextStyle(color: textGrey, fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _downloadShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentPurple,
                      foregroundColor: primaryWhite,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text('DOWNLOAD & SHARE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
