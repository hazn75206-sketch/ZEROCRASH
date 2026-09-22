import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  static const Color _bgDeep = Color(0xFF000000);
  static const Color _bgCard = Color(0xFF0A0A0A);
  static const Color _bgSection = Color(0xFF050505);
  static const Color _red = Color(0xFFFF0040);
  static const Color _border = Color(0xFF1A0A0A);
  static const Color _textMuted = Color(0xFF6B6B6B);
  static const Color _textSubtle = Color(0xFF3D3D3D);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        backgroundColor: _bgCard,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "Customer Service",
          style: TextStyle(
            color: _red,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: _border, height: 1),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _bgDeep,
              Color(0xFF050101),
              _bgDeep,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // === HEADER ICON ===
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: _red.withValues(alpha: 0.2), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.12),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    size: 56,
                    color: _red,
                  ),
                ),
                const SizedBox(height: 28),

                // === TITLE ===
                const Text(
                  "Need Help?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Hubungi kami melalui platform media sosial di bawah ini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 13,
                    fontFamily: 'ShareTechMono',
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // === CONTACT BUTTONS ===
                _buildContactButton(
                  label: "Telegram",
                  subtitle: "@Alexandernotdev",
                  icon: FontAwesomeIcons.telegram,
                  brandColor: const Color(0xFF2AABEE),
                  url: "https://t.me/zerocrashutmnotdev",
                ),
                const SizedBox(height: 12),
                _buildContactButton(
                  label: "WhatsApp",
                  subtitle: "+62 858-3922 9450",
                  icon: FontAwesomeIcons.whatsapp,
                  brandColor: const Color(0xFF25D366),
                  url: "https://wa.me/625839229450",
                ),
                const SizedBox(height: 12),
                _buildContactButton(
                  label: "TikTok",
                  subtitle: "@sanzxit",
                  icon: FontAwesomeIcons.tiktok,
                  brandColor: Colors.white,
                  url: "https://www.tiktok.com/@sanzxit?_r=1&_t=ZS-932NwfrWU5o",
                ),
                const SizedBox(height: 12),
                _buildContactButton(
                  label: "Instagram",
                  subtitle: "@darkness_reals",
                  icon: FontAwesomeIcons.instagram,
                  brandColor: const Color(0xFFE1306C),
                  url: "https://www.instagram.com/darkness_reals?igsh=MWM2MDl5NXg0bTJpNg==",
                ),

                const SizedBox(height: 50),

                // === FOOTER ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded, color: _textSubtle, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      "ZERO CRASH  Support",
                      style: TextStyle(
                        color: _textSubtle,
                        fontSize: 11,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color brandColor,
    required String url,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(18),
        splashColor: _red.withValues(alpha: 0.06),
        highlightColor: _red.withValues(alpha: 0.03),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: brandColor.withValues(alpha: 0.15)),
                ),
                child: FaIcon(
                  icon,
                  color: brandColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 18),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _bgSection,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: _textSubtle,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}