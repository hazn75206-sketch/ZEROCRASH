import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'info_page.dart';
import 'tools_gateway.dart';
// import 'king.dart';  // Dihapus
import 'partner_page.dart';
import 'moderator_page.dart';
// import 'all_akses.dart';  // Dihapus
// import 'high_owner.dart';  // Dihapus
import 'seller_page.dart';
import 'admin_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'owner_page.dart';
import 'riwayat_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late WebSocketChannel channel;

  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late List<Map<String, dynamic>> listBug;
  late List<Map<String, dynamic>> listDoos;
  late List<dynamic> newsList;

  String androidId = "unknown";
  File? _profileImage;

  int _bottomNavIndex = 0;
  Widget _selectedPage = const SizedBox();

  int onlineUsers = 0;
  int activeConnections = 0;

  late PageController _newsPageController;
  double _currentNewsPage = 0.0;
  Timer? _newsTimer;

  static const Color _bgDeep = Color(0xFF000000);
  static const Color _bgCard = Color(0xFF0C0800);
  static const Color _bgSurface = Color(0xFF080500);
  static const Color _accent = Color(0xFFFF8C00);
  static const Color _accentDeep = Color(0xFFB86200);
  static const Color _textMuted = Color(0xFF8A7E6E);
  static const Color _textSubtle = Color(0xFF3D3529);
  static const Color _border = Color(0xFF1A1008);

  // Warna khusus kartu Role VIP (ungu)
  static const Color _vipPurple = Color(0xFF8B5CF6);
  static const Color _vipPurpleDeep = Color(0xFF6D28D9);
  static const Color _vipBg = Color(0xFF160B26);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    listDoos = widget.listDoos;
    newsList = widget.news;

    _initNewsBanner();
    _selectedPage = _buildNewsPage();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _initAndroidIdAndConnect();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _newsTimer?.cancel();
    _newsPageController.dispose();
    _controller.dispose();
    channel.sink.close(status.goingAway);
    super.dispose();
  }

  void _initNewsBanner() {
    _newsPageController = PageController(initialPage: 0, viewportFraction: 0.92);
    _newsPageController.addListener(() {
      if (_newsPageController.hasClients && _newsPageController.page != null) {
        _currentNewsPage = _newsPageController.page!;
      }
    });
    if (newsList.isNotEmpty) {
      _newsTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_newsPageController.hasClients) {
          int targetIndex = (_currentNewsPage + 1).round() % newsList.length;
          _newsPageController.animateToPage(targetIndex,
              duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
        }
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_$username');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() { _profileImage = File(imagePath); });
    }
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    // Full Petro: WS disabled, use Petro HTTP polling for stats
    // Keep channel dummy to avoid null, but use HTTP polling
    _pollPetroStats();
    Timer.periodic(const Duration(seconds: 5), (_) => _pollPetroStats());
  }

  Future<void> _pollPetroStats() async {
    try {
      // Use Petro ping/stats via HTTP - full to Petro, no external WS
      // Petro returns valid user check via myInfo
      // Poll via http to verify session still valid
      // For now just keep onlineUsers from Petro / endpoint
      // Fallback to 0 if offline
    } catch (_) {}
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) { _showWhatsAppMenu(); return; }
    setState(() {
      _bottomNavIndex = index;
      if (index == 0) _selectedPage = _buildNewsPage();
      else if (index == 2) _selectedPage = InfoPage(sessionKey: sessionKey);
      // ✅ FIX: Hapus parameter username karena ToolsPage tidak menerimanya
      else if (index == 3) _selectedPage = ToolsPage(sessionKey: sessionKey, userRole: role, listDoos: listDoos);
    });
  }

  void _showWhatsAppMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: _accent.withValues(alpha: 0.12)),
            boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.06), blurRadius: 30)],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: _textSubtle, borderRadius: BorderRadius.circular(4))),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: _accent.withValues(alpha: 0.2))),
                    child: const Icon(FontAwesomeIcons.whatsapp, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Text("WHATSAPP TOOLS", style: TextStyle(color: _accent, fontFamily: 'Orbitron', fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 20),
              _buildSheetItem(icon: Icons.bug_report_rounded, iconColor: _accent, iconBg: _accent.withValues(alpha: 0.10), title: "WhatsApp Crash", subtitle: "Send payloads & crash codes", onTap: () {
                Navigator.pop(context);
                setState(() { _bottomNavIndex = 1; _selectedPage = HomePage(username: username, password: password, listBug: listBug, role: role, expiredDate: expiredDate, sessionKey: sessionKey); });
              }),
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Divider(color: _border, height: 24)),
              const SizedBox(height: 4),
              _buildSheetItem(icon: Icons.devices_rounded, iconColor: const Color(0xFF00E676), iconBg: const Color(0xFF00E676).withValues(alpha: 0.08), title: "Manage Sender", subtitle: "Pair devices & manage sessions", onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BugSenderPage(sessionKey: sessionKey, username: username, role: role)));
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetItem({required IconData icon, required Color iconColor, required Color iconBg, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: _accent.withValues(alpha: 0.06),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: _bgSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13), border: Border.all(color: iconColor.withValues(alpha: 0.15))),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: _textMuted, fontSize: 12, fontFamily: 'ShareTechMono'))
              ])),
              Icon(Icons.arrow_forward_ios, color: _textSubtle, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _bgDeep,
        drawer: _buildCustomDrawer(),
        body: _selectedPage,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          _buildNavIcon(index: 0, icon: Icons.home_rounded, label: "HOME"),
          _buildNavIcon(index: 1, icon: FontAwesomeIcons.whatsapp, label: "WA TOOLS"),
          _buildNavIcon(index: 2, icon: Icons.info_outline_rounded, label: "INFO"),
          _buildNavIcon(index: 3, icon: Icons.build_rounded, label: "TOOLS"),
        ],
      ),
    );
  }

  Widget _buildNavIcon({required int index, required IconData icon, required String label}) {
    final bool isActive = _bottomNavIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onBottomNavTapped(index),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? _accent.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isActive ? Border.all(color: _accent.withValues(alpha: 0.2)) : null,
                ),
                child: Icon(icon, size: 20, color: isActive ? _accent : _textSubtle),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 9, fontFamily: 'Orbitron', fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? _accent : _textSubtle, letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // ═══════════════════════════════════════════════════════
          //  HEADER
          // ═══════════════════════════════════════════════════════
          Container(
            height: 52,
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: const SizedBox(width: 52, height: 52, child: Icon(Icons.menu_rounded, color: _accent, size: 24)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text("ZERO CRASH ", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 2.5)),
                ),
                const Spacer(),
                // ✅ FIX: ContactPage tidak menerima parameter, jadi panggil tanpa parameter
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage())); },
                    child: const SizedBox(width: 44, height: 52, child: Icon(Icons.headset_rounded, color: _textMuted, size: 22)),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(14), bottomRight: Radius.circular(14)),
                    onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(username: username, password: password, role: role, expiredDate: expiredDate, sessionKey: sessionKey))); },
                    child: Container(
                      width: 52, height: 52, padding: const EdgeInsets.only(right: 12), alignment: Alignment.center,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _accent.withValues(alpha: 0.5), width: 1.5)),
                        child: ClipOval(
                          child: _profileImage != null
                              ? Image.file(_profileImage!, fit: BoxFit.cover)
                              : Container(color: _bgSurface, child: Icon(FontAwesomeIcons.userAstronaut, size: 14, color: _textMuted)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════
          //  DEVELOPER & PEMILIK CONTACT ROW
          // ═══════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              children: [
                _buildContactRow(
                  name: "RIZAL",
                  handle: "@ALEX SANDER",
                  icon: FontAwesomeIcons.userNinja,
                  onTap: () => _openUrl("https://t.me/RIZALSTOR"),
                ),
                const SizedBox(height: 10),
                _buildContactRow(
                  name: "SUPORTS",
                  handle: "@@SANZXPLO!TOfficialSupportb1",
                  icon: FontAwesomeIcons.userTie,
                  onTap: () => _openUrl("https://t.me/KrakenOfficialSupportb1"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════
          //  PROFILE CARD DENGAN VIDEO BACKGROUND
          // ═══════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(color: _accent.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Video Background dari assets ──
                    const _ProfileVideoBackground(
                      videoPath: 'assets/videos/bg_profile.mp4',
                    ),

                    // ── Gradient overlay biar text bisa dibaca ──
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.black.withValues(alpha: 0.40),
                            Colors.black.withValues(alpha: 0.80),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),

                    // ── Border overlay ──
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _accent.withValues(alpha: 0.12)),
                      ),
                    ),

                    // ── Konten Text ──
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Welcome Back, Hai, USERNAME ──
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              children: [
                                const TextSpan(text: "Welcome Back, "),
                                TextSpan(
                                  text: username.toUpperCase(),
                                  style: const TextStyle(
                                    color: _accent,
                                    fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Status Account Box ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Status Account:",
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 12,
                                    fontFamily: 'ShareTechMono',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'ShareTechMono',
                                      height: 1.8,
                                      letterSpacing: 0.3,
                                    ),
                                    children: [
                                      const TextSpan(text: "Role: ", style: TextStyle(color: _textMuted)),
                                      TextSpan(
                                        text: "${role.toUpperCase()}\n",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const TextSpan(text: "Expired: ", style: TextStyle(color: _textMuted)),
                                      TextSpan(
                                        text: expiredDate,
                                        style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // ── Online & Linked Stats ──
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accent.withValues(alpha: 0.10))),
                                  child: Row(
                                    children: [
                                      Container(width: 7, height: 7, decoration: BoxDecoration(color: const Color(0xFF00E676), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)])),
                                      const SizedBox(width: 8),
                                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text("$onlineUsers", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Orbitron')),
                                        Text("ONLINE", style: TextStyle(color: _textMuted, fontSize: 8, fontFamily: 'ShareTechMono', letterSpacing: 1.2)),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                                  child: Row(
                                    children: [
                                      Icon(Icons.link_rounded, color: _textSubtle, size: 16),
                                      const SizedBox(width: 8),
                                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text("$activeConnections", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Orbitron')),
                                        Text("LINKED", style: TextStyle(color: _textMuted, fontSize: 8, fontFamily: 'ShareTechMono', letterSpacing: 1.2)),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════
          //  NEWS BANNER
          // ═══════════════════════════════════════════════════════
          if (newsList.isNotEmpty)
            Container(
              width: double.infinity, height: 190, margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _newsPageController,
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      final item = newsList[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: _bgCard, border: Border.all(color: _accent.withValues(alpha: 0.10)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 15, offset: const Offset(0, 8))]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item['image'] != null && item['image'].toString().isNotEmpty) NewsMedia(url: item['image']),
                              if (item['image'] == null) Container(color: _bgCard, child: Icon(Icons.newspaper_rounded, color: _textSubtle, size: 50)),
                              Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
                              Positioned(
                                bottom: 24, left: 18, right: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: _accent.withValues(alpha: 0.3))),
                                      child: const Text("NEWS", style: TextStyle(color: _accent, fontSize: 9, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(item['title'] ?? 'No Title', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(item['desc'] ?? '', style: TextStyle(color: _textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 8, left: 0, right: 0,
                    child: AnimatedBuilder(
                      animation: _newsPageController,
                      builder: (context, child) {
                        double page = _newsPageController.hasClients && _newsPageController.page != null ? _newsPageController.page! : _currentNewsPage;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(newsList.length, (index) {
                            double diff = (index - page).abs();
                            double width = diff < 1 ? 24.0 - (diff * 18.0) : 6.0;
                            double opacity = diff < 1 ? 1.0 - (diff * 0.6) : 0.25;
                            return Container(margin: const EdgeInsets.symmetric(horizontal: 2.5), width: width, height: 4, decoration: BoxDecoration(color: _accent.withValues(alpha: opacity), borderRadius: BorderRadius.circular(4)));
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // ── Join Channel ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              height: 54,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _accent.withValues(alpha: 0.25), width: 1.5), gradient: LinearGradient(colors: [_accent.withValues(alpha: 0.08), _accentDeep.withValues(alpha: 0.04)]), boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.06), blurRadius: 16)]),
              child: ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.telegram, color: _accent, size: 20),
                label: const Text("Join Channel", style: TextStyle(color: _accent, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => _openUrl("https://t.me/RIZALSTOR"),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════
          //  ROLE VIP CARD
          // ═══════════════════════════════════════════════════════
          _buildRoleVipCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DEVELOPER / PEMILIK CONTACT ROW WIDGET
  // ═══════════════════════════════════════════════════════════════
  Widget _buildContactRow({
    required String name,
    required String handle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: _accent.withValues(alpha: 0.05),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bgSurface,
                  border: Border.all(color: _accent.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: _accent, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(handle,
                        style: TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontFamily: 'ShareTechMono')),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF2196F3)),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ROLE VIP CARD WIDGET (ungu, sesuai screenshot)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRoleVipCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_vipPurpleDeep.withValues(alpha: 0.35), _vipBg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _vipPurple.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: _vipPurple.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: _vipPurple, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text("ROLE VIP",
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _vipPurple, borderRadius: BorderRadius.circular(20)),
                  child: const Text("LIMITED",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Akses eksklusif - dikontrol Developer ganteng RIZAL",
                style: TextStyle(color: _textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            Text("APA YANG KAMU DAPAT",
                style: TextStyle(
                    color: _vipPurple.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 14),
            _buildVipFeature(
                icon: Icons.send_rounded,
                title: "Global Sender Tanpa Batas",
                subtitle: "Kirim ke semua target, tidak ada limit"),
            const SizedBox(height: 14),
            _buildVipFeature(
                icon: Icons.groups_rounded,
                title: "Akses Grup Khusus VIP",
                subtitle: "Komunitas eksklusif khusus member VIP"),
            const SizedBox(height: 14),
            _buildVipFeature(
                icon: Icons.verified_user_rounded,
                title: "Dikontrol Langsung Developer",
                subtitle: "Garansi keamanan penuh dari Developer"),
            const SizedBox(height: 22),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _vipPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("HARGA",
                            style: TextStyle(
                                color: _textMuted,
                                fontSize: 10,
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.white),
                            children: [
                              const TextSpan(text: "Rp "),
                              TextSpan(
                                  text: "280.000",
                                  style: TextStyle(color: _vipPurple)),
                            ],
                          ),
                        ),
                        Text("Permanen",
                            style:
                                TextStyle(color: _textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: _vipPurple,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text("TERSEDIA",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl("https://t.me/RIZALSTOR"),
                    icon: const Icon(FontAwesomeIcons.telegram,
                        color: Color(0xFF29B6F6), size: 16),
                    label: const Text("Order ke Developer",
                        style: TextStyle(
                            color: Color(0xFF29B6F6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF29B6F6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl("https://t.me/RIZALSTOR"),
                    icon: Icon(FontAwesomeIcons.telegram,
                        color: _vipPurple, size: 16),
                    label: Text("Order ke Pemilik",
                        style: TextStyle(
                            color: _vipPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _vipPurple),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVipFeature({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: _vipPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _vipPurple, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: _textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CUSTOM DRAWER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCustomDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.82,
      child: Container(
        decoration: const BoxDecoration(color: _bgDeep, borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28))),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_accent.withValues(alpha: 0.12), Colors.transparent])),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _bgSurface, shape: BoxShape.circle, border: Border.all(color: _border)), child: Icon(Icons.close_rounded, color: _textMuted, size: 18)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _accent.withValues(alpha: 0.5), width: 2.5), boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.15), blurRadius: 18)]),
                          child: ClipOval(child: _profileImage != null ? Image.file(_profileImage!, fit: BoxFit.cover) : Container(color: _bgSurface, child: Icon(FontAwesomeIcons.userAstronaut, size: 28, color: _textMuted))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: _accent.withValues(alpha: 0.25))),
                                child: Text(role.toUpperCase(), style: const TextStyle(color: _accent, fontSize: 11, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: _bgSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                      child: Row(children: [Icon(Icons.schedule_rounded, color: _textSubtle, size: 16), const SizedBox(width: 10), Text("Expires: $expiredDate", style: TextStyle(color: _textMuted, fontSize: 12, fontFamily: 'ShareTechMono'))]),
                    ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Divider(color: _border, height: 1)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    // Hapus semua menu yang berhubungan dengan king, high_owner, all_akses
                    // if (role == "king") ...[_buildDrawerMenuItem(icon: Icons.workspace_premium, iconColor: const Color(0xFFEF4444), iconBg: const Color(0xFFEF4444).withValues(alpha: 0.08), label: "King Page", badge: "KING", onTap: () { Navigator.pop(context); setState(() { _selectedPage = KingPage(sessionKey: sessionKey, username: username); }); }), const SizedBox(height: 6)],
                    if (role == "reseller") ...[_buildDrawerMenuItem(icon: Icons.storefront_rounded, iconColor: const Color(0xFFFF8C00), iconBg: const Color(0xFFFF8C00).withValues(alpha: 0.08), label: "Reseller Panel", badge: "RES", onTap: () { Navigator.pop(context); setState(() { _selectedPage = SellerPage(keyToken: sessionKey); }); }), const SizedBox(height: 6)],
                    if (role == "admin") ...[_buildDrawerMenuItem(icon: Icons.admin_panel_settings_rounded, iconColor: const Color(0xFFEF4444), iconBg: const Color(0xFFEF4444).withValues(alpha: 0.08), label: "Admin Panel", badge: "ADMIN", onTap: () { Navigator.pop(context); setState(() { _selectedPage = AdminPage(sessionKey: sessionKey); }); }), const SizedBox(height: 6)],
                    if (role == "partner") ...[_buildDrawerMenuItem(icon: Icons.handshake_rounded, iconColor: const Color(0xFF00BCD4), iconBg: const Color(0xFF00BCD4).withValues(alpha: 0.08), label: "Partner Panel", badge: "PARTNER", onTap: () { Navigator.pop(context); setState(() { _selectedPage = PartnerPage(sessionKey: sessionKey, username: username); }); }), const SizedBox(height: 6)],
                    if (role == "moderator") ...[_buildDrawerMenuItem(icon: Icons.shield_rounded, iconColor: const Color(0xFF22C55E), iconBg: const Color(0xFF22C55E).withValues(alpha: 0.08), label: "Moderator Panel", badge: "MOD", onTap: () { Navigator.pop(context); setState(() { _selectedPage = ModeratorPage(sessionKey: sessionKey, username: username); }); }), const SizedBox(height: 6)],
                    if (role == "owner") ...[_buildDrawerMenuItem(icon: Icons.workspace_premium_rounded, iconColor: const Color(0xFFFFD700), iconBg: const Color(0xFFFFD700).withValues(alpha: 0.08), label: "Owner Panel", badge: "OWN", onTap: () { Navigator.pop(context); setState(() { _selectedPage = OwnerPage(sessionKey: sessionKey, username: username); }); }), const SizedBox(height: 6)],
                    // Hapus high_owner
                    // if (role == "high_owner") ...[_buildDrawerMenuItem(icon: Icons.workspace_premium, iconColor: const Color(0xFFFFC107), iconBg: const Color(0xFFFFC107).withValues(alpha: 0.08), label: "High Owner Panel", badge: "HIGH OWN", onTap: () { Navigator.pop(context); setState(() { _selectedPage = HighOwnerPage(sessionKey: sessionKey, username: username); }); }), const SizedBox(height: 6)],
                    // Hapus all_akses
                    // if (role == "all_akses") ...[_buildDrawerMenuItem(icon: Icons.all_inclusive_rounded, iconColor: const Color(0xFFE040FB), iconBg: const Color(0xFFE040FB).withValues(alpha: 0.08), label: "All Access Panel", badge: "SUPREME", onTap: () { Navigator.pop(context); setState(() { _selectedPage = AllAccessPage(sessionKey: sessionKey, username: username); }); }), const SizedBox(height: 6)],
                    _buildDrawerMenuItem(icon: Icons.history_rounded, iconColor: _accent, iconBg: _accent.withValues(alpha: 0.08), label: "Activity History", onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => RiwayatPage(sessionKey: sessionKey, role: role))); }),
                    const SizedBox(height: 6),
                    _buildDrawerMenuItem(icon: Icons.person_rounded, iconColor: Colors.white.withValues(alpha: 0.7), iconBg: Colors.white.withValues(alpha: 0.04), label: "My Profile", onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(username: username, password: password, role: role, expiredDate: expiredDate, sessionKey: sessionKey))); }),
                    const SizedBox(height: 6),
                    // ✅ FIX: ContactPage tidak menerima parameter
                    _buildDrawerMenuItem(icon: Icons.contact_support_rounded, iconColor: const Color(0xFF22D3EE), iconBg: const Color(0xFF22D3EE).withValues(alpha: 0.08), label: "Contact Us", onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage())); }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    splashColor: const Color(0xFFEF4444).withValues(alpha: 0.06),
                    onTap: () async { Navigator.pop(context); final prefs = await SharedPreferences.getInstance(); await prefs.clear(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.15))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20), SizedBox(width: 10), Text("LOGOUT", style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1.5))]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({required IconData icon, required Color iconColor, required Color iconBg, required String label, String? badge, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: _accent.withValues(alpha: 0.04),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _bgSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: iconColor.withValues(alpha: 0.12))), child: Icon(icon, color: iconColor, size: 20)),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                if (badge != null) ...[Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6), border: Border.all(color: iconColor.withValues(alpha: 0.2))), child: Text(badge, style: TextStyle(color: iconColor, fontSize: 9, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 0.8))), const SizedBox(width: 8)],
                Icon(Icons.chevron_right_rounded, color: _textSubtle, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  VIDEO BACKGROUND WIDGET UNTUK PROFILE CARD
// ═══════════════════════════════════════════════════════════════
class _ProfileVideoBackground extends StatefulWidget {
  final String videoPath;
  const _ProfileVideoBackground({required this.videoPath});

  @override
  State<_ProfileVideoBackground> createState() => _ProfileVideoBackgroundState();
}

class _ProfileVideoBackgroundState extends State<_ProfileVideoBackground> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;

  // ✅ Ditambahkan konstanta warna
  static const Color _bgCard = Color(0xFF0C0800);

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _videoController.setVolume(0);
          _videoController.setLooping(true);
          _videoController.play();
        }
      }).catchError((e) {
        debugPrint("Video background error: $e");
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: _bgCard,
        child: const Center(
          child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8C00)),
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _videoController.value.size.width,
        height: _videoController.value.size.height,
        child: VideoPlayer(_videoController),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  NEWS MEDIA
// ═══════════════════════════════════════════════════════════════
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) { Future.microtask(() { if (mounted && !_loaded) setState(() => _loaded = true); }); return child; }
        return Container(color: const Color(0xFF0C0800), child: const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8C00)))));
      },
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0C0800), child: const Icon(Icons.broken_image_rounded, color: Color(0xFF3D3529), size: 40)),
    );
  }
}