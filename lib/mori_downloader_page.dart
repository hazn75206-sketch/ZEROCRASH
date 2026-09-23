import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'mori/mori_api.dart';

class MoriDownloaderPage extends StatefulWidget {
  const MoriDownloaderPage({super.key});

  @override
  State<MoriDownloaderPage> createState() => _MoriDownloaderPageState();
}

class _MoriDownloaderPageState extends State<MoriDownloaderPage> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _platform;
  String? _errorMessage;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late AnimationController _spinController;

  final Color bgDark = const Color(0xFF00050B);
  final Color cardDark = const Color(0xFF0A1118);
  final Color primaryPurple = const Color(0xFF102A43);
  final Color accentPurple = const Color(0xFF00E5FF);
  final Color primaryWhite = Colors.white;
  final Color textGrey = const Color(0xFF78909C);

  static const String _apiBase = "https://private-server-production.up.railway.app";

  static const Map<String, Map<String, dynamic>> _platforms = {
    'tiktok': {'name': 'TikTok', 'icon': FontAwesomeIcons.tiktok},
    'instagram': {'name': 'Instagram', 'icon': FontAwesomeIcons.instagram},
    'youtube': {'name': 'YouTube', 'icon': FontAwesomeIcons.youtube},
    'facebook': {'name': 'Facebook', 'icon': FontAwesomeIcons.facebook},
    'twitter': {'name': 'Twitter/X', 'icon': FontAwesomeIcons.xTwitter},
    'pinterest': {'name': 'Pinterest', 'icon': FontAwesomeIcons.pinterest},
    'threads': {'name': 'Threads', 'icon': FontAwesomeIcons.threads},
    'bilibili': {'name': 'Bilibili', 'icon': FontAwesomeIcons.bilibili},
    'douyin': {'name': 'Douyin', 'icon': FontAwesomeIcons.tiktok},
    'rednote': {'name': 'RedNote', 'icon': FontAwesomeIcons.book},
    'pixiv': {'name': 'Pixiv', 'icon': FontAwesomeIcons.pixiv},
    'bandcamp': {'name': 'Bandcamp', 'icon': FontAwesomeIcons.bandcamp},
    'spotify': {'name': 'Spotify', 'icon': FontAwesomeIcons.spotify},
    'applemusic': {'name': 'Apple Music', 'icon': FontAwesomeIcons.apple},
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
    _spinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
    _spinController.dispose();
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

    _spinController.repeat();
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
      // Mori engine dulu (client-side, tanpa server). TikTok via TikWM.
      if (platform == 'tiktok') {
        try {
          final mori = await MoriApi.resolveTiktok(url);
          if (!mounted) return;
          setState(() => _result = Map<String, dynamic>.from(mori['data'] as Map));
          _initPreview();
          return;
        } catch (_) {
          // fallback ke Railway di bawah
        }
      }
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
      _spinController.stop();
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
        setState(() => _errorMessage = "Video tidak bisa diputar langsung. Gunakan UNDUH untuk simpan ke Galeri.");
      });
  }

  bool _isDownloading = false;
  double? _downloadProgress;
  int _downloadReceived = 0;
  int? _downloadTotal;

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _unduh() async {
    final urls = (_result?['urls'] as List?) ?? [];
    if (urls.isEmpty || _isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadReceived = 0;
      _downloadTotal = null;
    });
    final headers = _headersFor(_platform ?? 'universal');
    http.Client? client;
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      final url = urls[0].toString();
      final isPhoto = RegExp(r'\.(jpg|jpeg|png|webp)(\?|$)').hasMatch(url.split('?')[0].toLowerCase());
      client = http.Client();
      final req = http.Request('GET', Uri.parse(url));
      req.headers.addAll(headers);
      final streamed = await client.send(req).timeout(const Duration(seconds: 120));
      if (streamed.statusCode != 200) throw Exception("Server mengembalikan ${streamed.statusCode}.");
      _downloadTotal = streamed.contentLength;
      final bytes = <int>[];
      int received = 0;
      await for (final chunk in streamed.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        final total = _downloadTotal;
        if (mounted) {
          setState(() {
            _downloadReceived = received;
            if (total != null && total > 0) {
              _downloadProgress = received / total;
            } else {
              _downloadProgress = null;
            }
          });
        }
      }
      final tempDir = await getTemporaryDirectory();
      final ext = isPhoto ? 'jpg' : 'mp4';
      final file = File('${tempDir.path}/mori_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes);
      if (isPhoto) {
        await Gal.putImage(file.path);
      } else {
        await Gal.putVideo(file.path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Media tersimpan di Galeri.',
              style: TextStyle(color: primaryWhite)),
          backgroundColor: primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: TextStyle(color: primaryWhite)), backgroundColor: primaryPurple),
      );
    } finally {
      client?.close();
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
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
                          FaIcon(plat['icon'] as IconData, color: accentPurple, size: 18),
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
                            _isLoading
                                ? RotationTransition(
                                    turns: _spinController,
                                    child: Icon(Icons.hourglass_top, size: 20, color: primaryWhite),
                                  )
                                : Icon(Icons.download, size: 20, color: primaryWhite),
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
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
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
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(first, headers: _headersFor(_platform ?? 'universal'),
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, p) => p == null ? child : Center(child: CircularProgressIndicator(color: accentPurple)),
                          errorBuilder: (c, e, s) => Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('Gambar tidak bisa dimuat. Gunakan UNDUH.', style: TextStyle(color: accentPurple)),
                              )),
                    ),
                  ),
                const SizedBox(height: 12),
                if (meta != null)
                  Text('${meta['title'] ?? 'No Title'}',
                      style: TextStyle(color: primaryWhite, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Creator: ${meta?['creator'] ?? 'Unknown'} • ${urls.length} media',
                    style: TextStyle(color: textGrey, fontSize: 13)),
                if (_isDownloading) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 8,
                      backgroundColor: textGrey.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(accentPurple),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _downloadProgress != null
                        ? '${(_downloadProgress! * 100).toStringAsFixed(0)}% • ${_formatBytes(_downloadReceived)}${_downloadTotal != null ? ' / ${_formatBytes(_downloadTotal!)}' : ''}'
                        : 'Mengunduh... ${_formatBytes(_downloadReceived)}',
                    style: TextStyle(color: accentPurple, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isDownloading ? null : _unduh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentPurple,
                      foregroundColor: primaryWhite,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isDownloading ? Icons.hourglass_top : Icons.download, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                            _isDownloading
                                ? (_downloadProgress != null ? 'MENGUNDUH ${(_downloadProgress! * 100).toStringAsFixed(0)}%' : 'MENGUNDUH...')
                                : 'UNDUH',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', color: Colors.white)),
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
