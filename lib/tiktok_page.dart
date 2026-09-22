import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'mori/mori_api.dart';
import 'dart:io';

class TiktokDownloaderPage extends StatefulWidget {
  const TiktokDownloaderPage({super.key});

  @override
  State<TiktokDownloaderPage> createState() => _TiktokDownloaderPageState();
}

class _TiktokDownloaderPageState extends State<TiktokDownloaderPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _videoData;
  String? _errorMessage;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // --- TEMA WARNA HITAM PUTIH ---
  final Color bgDark = const Color(0xFF00050B);     // Background Utama
  final Color cardDark = const Color(0xFF0A1118);    // Warna Kartu
  final Color primaryPurple = const Color(0xFF102A43);
  final Color accentPurple = const Color(0xFF00E5FF);
  final Color primaryWhite = Colors.white;
  final Color textGrey = const Color(0xFF78909C);

  // Gradients
  final LinearGradient purpleGradient = const LinearGradient(
    colors: [const Color(0xFF102A43), Color(0xFFFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void dispose() {
    _urlController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _downloadTiktok() async {
    final raw = _urlController.text.trim();
    final match = RegExp(r'https?://[^\s]+').firstMatch(raw);
    final url = match != null ? match.group(0)! : raw;
    if (url.isEmpty) {
      setState(() {
        _errorMessage = "URL TikTok tidak boleh kosong.";
        _videoData = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _videoData = null;
      _videoController?.dispose();
      _chewieController?.dispose();
    });

    try {
      // Mori engine dulu (TikWM, tanpa watermark). Fallback Railway.
      try {
        final mori = await MoriApi.resolveTiktok(url);
        if (!mounted) return;
        setState(() {
          _videoData = Map<String, dynamic>.from(mori['data'] as Map);
        });
        _initializeVideoPlayer();
        setState(() => _isLoading = false);
        return;
      } catch (_) {
        // fallback Railway di bawah
      }
      final apiUrl = Uri.parse("https://private-server-production.up.railway.app/api/d/tiktok?url=$url");
      final response = await http.get(apiUrl);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == true && json['data'] != null) {
          setState(() {
            _videoData = json['data'];
          });
          _initializeVideoPlayer();
        } else {
          setState(() {
            _errorMessage = "Gagal mengambil data TikTok.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Gagal terhubung ke server.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  static const Map<String, String> _videoHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; RMX2189) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://www.tiktok.com/',
  };

  void _initializeVideoPlayer() {
    if (_videoData?['urls'] != null && _videoData!['urls'].isNotEmpty) {
      final videoUrl = _videoData!['urls'][0];
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: _videoHeaders,
      )
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: true,
              looping: false,
              showControls: true,
              materialProgressColors: ChewieProgressColors(
                playedColor: primaryPurple, // Diubah ke ungu
                handleColor: accentPurple, // Diubah ke ungu
                backgroundColor: textGrey.withValues(alpha: 0.3),
                bufferedColor: textGrey.withValues(alpha: 0.2),
              ),
            );
          });
        }).catchError((e) {
          if (!mounted) return;
          setState(() {
            _errorMessage = "Video tidak bisa diputar langsung. Gunakan UNDUH untuk simpan & putar offline.";
          });
        });
    }
  }

  bool _isDownloading = false;

  Future<void> _unduhVideo() async {
    if (_videoData?['urls'] == null || _videoData!['urls'].isEmpty) return;
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      final videoUrl = _videoData!['urls'][0];
      final response = await http.get(Uri.parse(videoUrl), headers: _videoHeaders).timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) throw Exception("Server mengembalikan ${response.statusCode}.");
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/tiktok_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(response.bodyBytes);

      await Gal.putVideo(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video tersimpan di Galeri.',
              style: TextStyle(color: primaryWhite)),
          backgroundColor: primaryPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: TextStyle(color: primaryWhite)),
          backgroundColor: primaryPurple, // Diubah ke ungu
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'TIKTOK DOWNLOADER',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: primaryWhite,
          ),
        ),
        backgroundColor: bgDark,
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryWhite),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Input Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryPurple.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      style: TextStyle(color: primaryWhite, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Masukkan URL TikTok',
                        labelStyle: TextStyle(color: accentPurple),
                        hintText: 'Contoh: https://vt.tiktok.com/xxx/',
                        hintStyle: TextStyle(color: textGrey),
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
                        suffixIcon: _isLoading
                            ? Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: accentPurple,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _downloadTiktok,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: primaryWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: primaryPurple.withValues(alpha: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isLoading ? Icons.hourglass_top : Icons.download, size: 20, color: primaryWhite),
                            const SizedBox(width: 8),
                            Text(
                              _isLoading ? 'PROSES...' : 'DOWNLOAD',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Orbitron',
                                  color: primaryWhite
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: accentPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: accentPurple, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Video Result
              if (_videoData != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Video Preview
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: primaryPurple.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Video Header
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: purpleGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam, color: primaryWhite, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      "VIDEO PREVIEW",
                                      style: TextStyle(
                                        color: primaryWhite,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (_chewieController != null)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primaryPurple.withValues(alpha: 0.5)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryPurple.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                      aspectRatio: _videoController!.value.aspectRatio,
                                      child: Chewie(controller: _chewieController!),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00050B).withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: accentPurple),
                                        SizedBox(height: 16),
                                        Text(
                                          'Loading video...',
                                          style: TextStyle(
                                            color: accentPurple,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Video Info
                              if (_videoData?['metadata'] != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00050B).withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primaryPurple.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _videoData!['metadata']['title'] ?? 'No Title',
                                        style: TextStyle(
                                          color: primaryWhite,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.person, color: accentPurple, size: 16),
                                          SizedBox(width: 8),
                                          Text(
                                            'Creator: ${_videoData!['metadata']['creator'] ?? 'Unknown'}',
                                            style: TextStyle(
                                              color: textGrey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Unduh Button (save ke Galeri Movies)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isDownloading ? null : _unduhVideo,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentPurple,
                                    foregroundColor: primaryWhite,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    shadowColor: accentPurple.withValues(alpha: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_isDownloading ? Icons.hourglass_top : Icons.download, size: 20, color: primaryWhite),
                                      SizedBox(width: 8),
                                      Text(
                                        _isDownloading ? 'MENGUNDUH...' : 'UNDUH',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Orbitron',
                                            color: primaryWhite
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Placeholder
              if (_videoData == null && !_isLoading && _errorMessage == null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library,
                          size: 80,
                          color: primaryPurple.withValues(alpha: 0.3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'TikTok Downloader',
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 18,
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Masukkan URL TikTok untuk mendownload video',
                            style: TextStyle(
                              color: textGrey,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}