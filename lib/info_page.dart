import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InfoPage extends StatefulWidget {
  final String sessionKey;

  const InfoPage({super.key, required this.sessionKey});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  bool isLoading = true;

  bool isApiOnline = false;
  int apiPingMs = 0;
  Color apiStatusColor = const Color(0xFF3D2A00);
  String apiStatusText = "CHECKING...";
  Timer? _pingTimer;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Warna kuning gelap
  final Color bgDark = const Color(0xFF000000);
  final Color cardBg = const Color(0xFF0D0800);
  final Color cardBgAlt = const Color(0xFF120A00);
  final Color borderLight = const Color(0xFF2A1A00);
  final Color borderSubtle = const Color(0xFF1A0F00);
  final Color textMain = Colors.white;
  final Color textSub = const Color(0xFF8B7A60);
  final Color accentGold = const Color(0xFFB8860B);
  final Color accentGoldDim = const Color(0xFF8B6508);
  final Color accentGoldGlow = const Color(0xFFDAA520);
  final Color deepGold = const Color(0xFF6B4C00);

  final List<Map<String, dynamic>> rulesList = [
    {
      "title": "NO ACCOUNT BARTERING",
      "icon": Icons.swap_horizontal_circle_outlined,
      "desc": "Akun eksklusif DarkVerse tidak boleh ditukar dengan barang, jasa, atau akun lain dalam bentuk apa pun. Pelanggaran log akan terpantau.",
    },
    {
      "title": "STRICTLY PERSONAL USE",
      "icon": Icons.person_off_outlined,
      "desc": "Setiap akun terenkripsi untuk satu pengguna dan hanya boleh diakses oleh pemilik perangkat yang mendaftar (terikat Device ID).",
    },
    {
      "title": "RESELLING PROHIBITED",
      "icon": Icons.money_off_csred_outlined,
      "desc": "Member reguler dilarang memperjualbelikan akun. Akses penjualan eksklusif milik role berwenang (Partner, Owner, atau Reseller).",
    },
    {
      "title": "ILLEGAL DURATION SALES",
      "icon": Icons.timer_off_outlined,
      "desc": "Sangat dilarang membagi atau menjual akses eceran (harian, mingguan, trial) yang mengelabui skema periode resmi.",
    },
    {
      "title": "PRICE DUMPING BAN",
      "icon": Icons.trending_down_rounded,
      "desc": "Dilarang keras merusak standar harga pasar (banting harga) di bawah kesepakatan jaminan keamanan platform kami.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchServerInfo();
    _startApiPingLoop();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchServerInfo() async {
    try {
      await http
          .get(Uri.parse(
              'http://private02.angkasanyabobo.my.id:1315/getServerInfo?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 5));
      if (mounted) setState(() => isLoading = false);
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startApiPingLoop() {
    _checkApiPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkApiPing());
  }

  Future<void> _checkApiPing() async {
    final start = DateTime.now();
    try {
      final res = await http
          .get(Uri.parse(
              'http://private02.angkasanyabobo.my.id:1315/ping?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 3));
      final duration = DateTime.now().difference(start).inMilliseconds;

      if (res.statusCode == 200 && mounted) {
        setState(() {
          isApiOnline = true;
          apiPingMs = duration;
          if (duration < 200) {
            apiStatusColor = const Color(0xFFB8860B);
          } else if (duration < 500) {
            apiStatusColor = const Color(0xFFDAA520);
          } else {
            apiStatusColor = const Color(0xFF8B6508);
          }
          apiStatusText = "SYS.ONLINE :: ${duration}ms";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isApiOnline = false;
          apiPingMs = 0;
          apiStatusColor = const Color(0xFF3D2A00);
          apiStatusText = "SYS.OFFLINE :: DEST";
        });
      }
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentGold.withOpacity(
                          0.3 + _pulseAnimation.value * 0.7),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentGold
                            .withOpacity(_pulseAnimation.value * 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accentGold,
                      backgroundColor: const Color(0xFF1A0F00),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              "AUTHENTICATING",
              style: TextStyle(
                color: accentGold.withOpacity(0.6),
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 28),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: apiStatusColor.withOpacity(0.3 + _glowAnimation.value * 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: apiStatusColor.withOpacity(_glowAnimation.value * 0.08),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: apiStatusColor,
                  boxShadow: [
                    BoxShadow(
                      color: apiStatusColor
                          .withOpacity(_glowAnimation.value * 0.8),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  apiStatusText,
                  style: TextStyle(
                    color: apiStatusColor == const Color(0xFF3D2A00)
                        ? textSub
                        : apiStatusColor,
                    fontFamily: 'ShareTechMono',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0F00),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: borderLight.withOpacity(0.5), width: 0.5),
                ),
                child: Icon(Icons.memory,
                    color: textSub.withOpacity(0.4), size: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: accentGold,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: accentGold.withOpacity(0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B5A30),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              fontFamily: 'Orbitron',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(int index, Map<String, dynamic> rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSubtle, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0F00),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF3D2A00), width: 0.8),
                  ),
                  child: Center(
                    child: Icon(rule['icon'], color: accentGoldDim, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "0${index + 1}",
                            style: TextStyle(
                              color: deepGold.withOpacity(0.4),
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rule['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                fontFamily: 'Orbitron',
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rule['desc'],
                        style: const TextStyle(
                          color: Color(0xFF7A6A50),
                          fontSize: 12,
                          height: 1.6,
                          fontFamily: 'ShareTechMono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPenaltyBox() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16, bottom: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2A1A00).withOpacity(0.6 + _pulseAnimation.value * 0.2),
                const Color(0xFF000000),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B6508)
                  .withOpacity(0.3 + _pulseAnimation.value * 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8860B)
                    .withOpacity(_pulseAnimation.value * 0.06),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D2A00),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFF5C3D00).withOpacity(0.5),
                      width: 0.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFB8860B), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "VIOLATION PENALTY",
                      style: TextStyle(
                        color: Color(0xFFB8860B),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Jika pengguna terdeteksi melanggar salah satu protokol kerahasiaan & aturan di atas secara sengaja:",
                style: TextStyle(
                  color: Color(0xFF8B7A60),
                  fontSize: 12,
                  fontFamily: 'ShareTechMono',
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0F00),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF8B6508).withOpacity(0.35),
                      width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_forever_rounded,
                        color: Color(0xFFB8860B), size: 20),
                    SizedBox(width: 10),
                    Text(
                      "AKUN DIHAPUS PERMANEN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "TIDAK ADA PENGEMBALIAN SALDO ATAU KOMPENSASI.",
                style: TextStyle(
                  color: Color(0xFF8B5A30),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'ShareTechMono',
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0D0800),
            border: Border.all(
                color: const Color(0xFF2A1A00).withOpacity(0.6), width: 1),
          ),
          child: const Center(
            child: Icon(Icons.shield_moon_rounded,
                color: Color(0xFF3D2A00), size: 24),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Peraturan ini dibuat semata-mata untuk menjaga keamanan, kenyamanan, dan kestabilan ekosistem server DarkVerse. Dengan mengakses aplikasi, Anda secara otomatis menyetujui seluruh protokol di atas.",
            style: TextStyle(
              color: Color(0xFF4A3A20),
              fontSize: 11,
              fontStyle: FontStyle.italic,
              fontFamily: 'ShareTechMono',
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 1,
              decoration: BoxDecoration(
                color: const Color(0xFF2A1A00),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.circle, color: const Color(0xFF3D2A00), size: 5),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 1,
              decoration: BoxDecoration(
                color: const Color(0xFF2A1A00),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "DARKVERSE © ${DateTime.now().year}",
          style: const TextStyle(
            color: Color(0xFF2A1A00),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'Orbitron',
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingScreen();

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: bgDark,
              elevation: 0,
              pinned: true,
              automaticallyImplyLeading: false,
              expandedHeight: 70,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                title: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentGold,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: accentGold.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "EULA & SYSTEM INFO",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                centerTitle: false,
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF2A1A00),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatusHeader(),
                  _buildSectionTitle("USER PROTOCOLS"),
                  ...rulesList.asMap().entries
                      .map((e) => _buildRuleCard(e.key, e.value))
                      .toList(),
                  _buildPenaltyBox(),
                  _buildFooter(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
