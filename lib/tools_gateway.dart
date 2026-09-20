import 'dart:ui';
import 'package:flutter/material.dart';
import 'manage_server.dart';
import 'wifi_internal.dart';
import 'wifi_external.dart';
import 'ddos_panel.dart';
import 'nik_check.dart';
import 'tiktok_page.dart';
import 'instagram_page.dart';
import 'qr_gen.dart';
import 'domain_page.dart';
import 'spam_ngl.dart';
import 'anime.dart';
import 'hentai_page.dart' as hentai;

class ToolsPage extends StatelessWidget {
  final String sessionKey;
  final String userRole;
  final List<Map<String, dynamic>> listDoos;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.listDoos,
  });

  // === COLOR PALETTE ===
  static const Color _bgDeep = Color(0xFF000000);
  static const Color _bgCard = Color(0xFF0A0A0A);
  static const Color _bgItem = Color(0xFF050505);
  static const Color _red = Color(0xFFFF0040);
  static const Color _redDark = Color(0xFF8B0020);
  static const Color _redGlow = Color(0xFFFF0040);
  static const Color _textMuted = Color(0xFF6B6B6B);
  static const Color _textSubtle = Color(0xFF3D3D3D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // === HEADER ===
            _buildHeader(),
            const SizedBox(height: 32),

            // === STAT BAR ===
            _buildStatBar(),
            const SizedBox(height: 28),

            // === TOOL CATEGORIES ===
            _buildCategoryTile(
              icon: Icons.flash_on,
              title: "DDoS Tools",
              subtitle: "Attack & Server",
              children: [
                _buildToolItem(
                  context: context,
                  icon: Icons.flash_on,
                  label: "Attack Panel",
                  badge: "LIVE",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttackPanel(
                          sessionKey: sessionKey,
                          listDoos: listDoos,
                        ),
                      ),
                    );
                  },
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.dns,
                  label: "Manage Server",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageServerPage(keyToken: sessionKey),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildCategoryTile(
              icon: Icons.wifi,
              title: "Network",
              subtitle: "WiFi & Spam",
              children: [
                _buildToolItem(
                  context: context,
                  icon: Icons.newspaper_outlined,
                  label: "Spam NGL",
                  badge: "NEW",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NglPage()));
                  },
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.wifi_off,
                  label: "WiFi Killer (Internal)",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => WifiKillerPage()));
                  },
                ),
                if (userRole == "vip" || userRole == "owner")
                  _buildToolItem(
                    context: context,
                    icon: Icons.router,
                    label: "WiFi Killer (External)",
                    badge: "VIP",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WifiInternalPage(sessionKey: sessionKey)));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),

            _buildCategoryTile(
              icon: Icons.search,
              title: "OSINT",
              subtitle: "Investigation",
              children: [
                _buildToolItem(
                  context: context,
                  icon: Icons.badge,
                  label: "NIK Detail",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NikCheckerPage()));
                  },
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.domain,
                  label: "Domain OSINT",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DomainOsintPage()));
                  },
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.person_search,
                  label: "Phone Lookup",
                  locked: true,
                  onTap: () => _showComingSoon(context),
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.email,
                  label: "Email OSINT",
                  locked: true,
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildCategoryTile(
              icon: Icons.download,
              title: "Downloader",
              subtitle: "Social Media",
              children: [
                _buildToolItem(
                  context: context,
                  icon: Icons.video_library,
                  label: "TikTok Downloader",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TiktokDownloaderPage()));
                  },
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.camera_alt,
                  label: "Instagram Downloader",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InstagramDownloaderPage()));
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildCategoryTile(
              icon: Icons.build,
              title: "Utilities",
              subtitle: "Extra Tools",
              children: [
                _buildToolItem(
                  context: context,
                  icon: Icons.qr_code,
                  label: "QR Generator",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const QrGeneratorPage()));
                  },
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.security,
                  label: "IP Scanner",
                  locked: true,
                  onTap: () => _showComingSoon(context),
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.network_check,
                  label: "Port Scanner",
                  locked: true,
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildCategoryTile(
              icon: Icons.movie_filter,
              title: "Watch",
              subtitle: "Entertainment & Media",
              children: [
                _buildToolItem(
                  context: context,
                  icon: Icons.live_tv,
                  label: "Anime Streaming",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeAnimePage()));
                  },
                ),
                _buildToolItem(
                  context: context,
                  icon: Icons.local_fire_department,
                  label: "Hentai Media",
                  badge: "18+",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const hentai.HomeScreen()));
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildCategoryTile(
              icon: Icons.rocket_launch,
              title: "Quick Access",
              subtitle: "Favorites",
              children: [
                _buildToolItem(
                  context: context,
                  icon: Icons.star_border,
                  label: "Add Quick Access",
                  locked: true,
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),

            const SizedBox(height: 40),
            // === FOOTER ===
            Center(
              child: Text(
                "v2.0 — All tools are for educational purposes only.",
                style: TextStyle(
                  color: _textSubtle,
                  fontSize: 11,
                  fontFamily: 'ShareTechMono',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // === HEADER WIDGET ===
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _bgCard,
            _bgCard.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: _red.withOpacity(0.06),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _red.withOpacity(0.2)),
                ),
                child: Icon(Icons.shield, color: _red, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TOOLS DASHBOARD",
                      style: TextStyle(
                        color: _red,
                        fontSize: 20,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Advanced Security & OSINT Tools",
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _red.withOpacity(0.25)),
                ),
                child: Text(
                  userRole.toUpperCase(),
                  style: const TextStyle(
                    color: _red,
                    fontSize: 11,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === STAT BAR ===
  Widget _buildStatBar() {
    return Row(
      children: [
        _buildStatChip(
          icon: Icons.flash_on,
          label: "${listDoos.length} Methods",
          color: _red,
        ),
        const SizedBox(width: 10),
        _buildStatChip(
          icon: Icons.category,
          label: "7 Categories",
          color: _red,
        ),
        const SizedBox(width: 10),
        _buildStatChip(
          icon: Icons.lock,
          label: userRole.toUpperCase(),
          color: _red,
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.withOpacity(0.7), size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.85),
                  fontSize: 11,
                  fontFamily: 'ShareTechMono',
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === CATEGORY TILE (Accordion) ===
  Widget _buildCategoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: _red.withOpacity(0.03),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          colorScheme: const ColorScheme.dark(
            surfaceContainerHighest: Colors.transparent,
          ),
        ),
        child: ExpansionTile(
          iconColor: _red,
          collapsedIconColor: _red.withOpacity(0.4),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _red.withOpacity(0.15)),
            ),
            child: Icon(icon, color: _red, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: _red,
              fontSize: 15,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: _textMuted,
              fontSize: 12,
              fontFamily: 'ShareTechMono',
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.only(left: 18, right: 18, bottom: 14, top: 2),
              child: Column(
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === TOOL ITEM ===
  Widget _buildToolItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? badge,
    bool locked = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _bgItem,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: _red.withOpacity(0.08),
          highlightColor: _red.withOpacity(0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: locked
                        ? _textSubtle.withOpacity(0.3)
                        : _red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: locked ? _textMuted.withOpacity(0.4) : _red.withOpacity(0.8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: locked ? _textMuted.withOpacity(0.5) : Colors.white.withOpacity(0.9),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  _buildBadge(badge),
                  const SizedBox(width: 10),
                ],
                if (locked)
                  Icon(Icons.lock_outline, color: _textSubtle, size: 14)
                else
                  Icon(Icons.arrow_forward_ios, color: _red.withOpacity(0.3), size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === BADGE WIDGET ===
  Widget _buildBadge(String text) {
    Color bgColor;
    Color textColor;

    switch (text.toUpperCase()) {
      case "LIVE":
        bgColor = Colors.red.withOpacity(0.15);
        textColor = Colors.redAccent;
        break;
      case "NEW":
        bgColor = _red.withOpacity(0.12);
        textColor = _red;
        break;
      case "VIP":
        bgColor = Colors.amber.withOpacity(0.12);
        textColor = Colors.amber;
        break;
      case "18+":
        bgColor = Colors.pink.withOpacity(0.12);
        textColor = Colors.pinkAccent;
        break;
      default:
        bgColor = _red.withOpacity(0.10);
        textColor = _red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // === COMING SOON DIALOG ===
  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _red.withOpacity(0.2)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lock_clock, color: _red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Coming Soon",
              style: TextStyle(color: _red, fontFamily: 'Orbitron', fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          "Fitur ini masih dalam tahap pengembangan. Nantikan update selanjutnya.",
          style: TextStyle(color: _textMuted, fontSize: 13),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: _red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withOpacity(0.25)),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(color: _red, fontFamily: 'Orbitron', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}