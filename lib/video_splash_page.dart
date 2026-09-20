import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';

class VideoSplashPage extends StatefulWidget {
  final Map<String, dynamic> dashboardArgs;

  const VideoSplashPage({super.key, required this.dashboardArgs});

  @override
  State<VideoSplashPage> createState() => _VideoSplashPageState();
}

class _VideoSplashPageState extends State<VideoSplashPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() async {
    _controller = VideoPlayerController.asset('assets/videos/login.mp4');

    try {
      await _controller.initialize();
      await _controller.setVolume(1.0);
      await _controller.setLooping(false);

      _controller.addListener(_onVideoEnd);
      await _controller.play();

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      _goToDashboard();
    }
  }

  void _onVideoEnd() {
    if (!_navigated &&
        _controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _goToDashboard();
    }
  }

  void _goToDashboard() {
    if (_navigated) return;
    _navigated = true;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            username: widget.dashboardArgs['username'],
            password: widget.dashboardArgs['password'],
            role: widget.dashboardArgs['role'],
            sessionKey: widget.dashboardArgs['key'],
            expiredDate: widget.dashboardArgs['expiredDate'],
            listBug: List<Map<String, dynamic>>.from(
                widget.dashboardArgs['listBug'] ?? []),
            listDoos: List<Map<String, dynamic>>.from(
                widget.dashboardArgs['listDoos'] ?? []),
            news: List<Map<String, dynamic>>.from(
                widget.dashboardArgs['news'] ?? []),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Video Full Layar ---
          if (_isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF1744)),
              ),
            ),

          // --- Gradient overlay bawah biar tulisan terbaca ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // --- Tulisan ZERO CRASH  tengah bawah ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: const Text(
              "Titanic crash",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 35,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
          ),

          // --- Tombol Skip transparan kanan atas ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: GestureDetector(
              onTap: _goToDashboard,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Skip",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}