import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'video_splash_page.dart';

const String baseUrl = "https://private-server.banditflow.my.id:2014";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _glowPulse;

  // ===== Warna tema DarkVerse (Orange / Black) =====
  static const Color bgMain = Color(0xFF000000);
  static const Color bgCard = Color(0xFF0B0B0B);
  static const Color bgInput = Color(0xFF11213A);
  static const Color accentOrange = Color(0xFFFF9500);
  static const Color accentOrangeDark = Color(0xFFCC6A00);
  static const Color secondaryText = Color(0xFF9C8F82);
  static const Color borderDim = Color(0x33FF9500);
  static const Color borderInput = Color(0x40FF9500);
  static const Color textWhite = Colors.white;
  static const Color onlineGreen = Color(0xFF3DDC97);

  // ===== Daftar harga (Pricing Plan) =====
  final List<Map<String, String>> pricingPlans = const [
    {"duration": "1 Hari", "price": "Rp 10.000"},
    {"duration": "7 Hari", "price": "Rp 50.000"},
    {"duration": "30 Hari", "price": "Rp 150.000"},
    {"duration": "Lifetime", "price": "Rp 400.000"},
  ];

  @override
  void initState() {
    super.initState();
    _initAnim();
    initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeIn),
    );

    _glowPulse = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  void _navigateToVideoSplash(Map<String, dynamic> args) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoSplashPage(dashboardArgs: args),
      ),
    );
  }

  Map<String, dynamic> _buildArgs(
      dynamic data, String username, String password) {
    return {
      "username": username,
      "password": password,
      "role": data['role'],
      "key": data['key'],
      "expiredDate": data['expiredDate'],
      "listBug": (data['listBug'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      "listDoos": (data['listDDoS'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      "news": (data['news'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    };
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
          "$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          _navigateToVideoSplash(_buildArgs(data, savedUser, savedPass));
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = userController.text.trim();
    final password = passController.text.trim();
    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("$baseUrl/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );
      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showPopup(
          title: "Access Expired",
          message: "Masa akses Anda telah habis.\nSilakan perpanjang akses.",
          showContact: true,
        );
      } else if (validData['valid'] != true) {
        final String errorMsg = (validData['message'] ?? "").toLowerCase();
        if (errorMsg.contains("perangkat") ||
            errorMsg.contains("device") ||
            errorMsg.contains("another")) {
          _showPopup(
            title: "Sesi Aktif",
            message:
                "Akun ini sedang login di perangkat lain.\nSilakan logout di perangkat lama.",
          );
        } else {
          _showPopup(
            title: "Login Gagal",
            message: "Username atau password salah.",
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);
        _navigateToVideoSplash(_buildArgs(validData, username, password));
      }
    } catch (e) {
      _showPopup(
        title: "Connection Error",
        message: "Gagal terhubung ke server.",
      );
    }

    setState(() => isLoading = false);
  }

  void _showPopup({
    required String title,
    required String message,
    bool showContact = false,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0503),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentOrange.withOpacity(0.3), width: 1),
        ),
        title: Text(title,
            style: const TextStyle(
                color: accentOrange,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        content: Text(message,
            style: const TextStyle(color: secondaryText, fontSize: 14)),
        actions: [
          if (showContact)
            TextButton(
              onPressed: () async {
                await launchUrl(Uri.parse("https://t.me/farz_to"),
                    mode: LaunchMode.externalApplication);
              },
              child: const Text("Contact Admin",
                  style: TextStyle(
                      color: accentOrange, fontWeight: FontWeight.w600)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Close", style: TextStyle(color: secondaryText)),
          ),
        ],
      ),
    );
  }

  void _showPricingPlan() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderDim, width: 1),
            boxShadow: [
              BoxShadow(
                color: accentOrange.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond_outlined,
                      color: accentOrange, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "PRICING PLAN",
                    style: TextStyle(
                      color: accentOrange,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close,
                        color: secondaryText.withOpacity(0.7), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Pilih durasi akses DarkVerse",
                style: TextStyle(
                    color: secondaryText.withOpacity(0.8), fontSize: 12),
              ),
              const SizedBox(height: 18),
              ...pricingPlans.map((plan) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgInput.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderInput, width: 1),
                    ),
                    child: Row(
                      children: [
                        Text(
                          plan["duration"]!,
                          style: const TextStyle(
                            color: textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          plan["price"]!,
                          style: const TextStyle(
                            color: accentOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final url = Uri.parse("https://t.me/Alexandernotdev");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text(
                    "Hubungi Admin untuk Beli Akses",
                    style:
                        TextStyle(color: accentOrange, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgMain,
      body: Stack(
        children: [
          // Background glow orange
          Positioned.fill(
            child: CustomPaint(
              painter: _OrangeGlowPainter(animValue: _glowPulse.value),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.03),

                  // ===== Header bar oranye (mirip banner "DARKVERSE") =====
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildHeaderBar(),
                  ),

                  SizedBox(height: size.height * 0.02),

                  // ===== Card utama =====
                  SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderDim, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBrandRow(),
                          const SizedBox(height: 24),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildInput(
                                  controller: userController,
                                  hint: "Username",
                                  icon: Icons.person_outline_rounded,
                                  obscure: false,
                                ),
                                const SizedBox(height: 16),
                                _buildInput(
                                  controller: passController,
                                  hint: "Password",
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscurePassword,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: secondaryText,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword =
                                          !_obscurePassword);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _buildLoginButton(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildPricingPlanButton(),
                          const SizedBox(height: 18),
                          _buildSocialRow(),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.03),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: accentOrange.withOpacity(0.08),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "By continuing, you agree to our Terms of Service",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "v7.5",
                          style: TextStyle(
                            color: accentOrange.withOpacity(0.25),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Header bar oranye dengan logo bulat + judul + QR icon =====
  Widget _buildHeaderBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [accentOrange, accentOrangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accentOrange.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildLogoBadge(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DARKVERSE",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.85),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  "Secure Access to DarkVerse",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.qr_code_2_rounded,
              color: Colors.black.withOpacity(0.7), size: 26),
        ],
      ),
    );
  }

  // ===== Logo bulat (fallback ikon jika asset tidak ada, agar tidak error) =====
  Widget _buildLogoBadge({double size = 90}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        border: Border.all(color: Colors.black.withOpacity(0.3), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.whatshot_rounded,
            color: accentOrange,
            size: size * 0.55,
          );
        },
      ),
    );
  }

  // ===== Baris brand: logo besar + nama + badge + status =====
  Widget _buildBrandRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentOrange, width: 2),
            boxShadow: [
              BoxShadow(
                color: accentOrange.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: _buildLogoBadge(size: 64),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "DARKVERSE",
                style: TextStyle(
                  color: textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: accentOrange.withOpacity(0.4)),
                ),
                child: const Text(
                  "Secure Access to DarkVerse",
                  style: TextStyle(
                    color: accentOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: onlineGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    "Online",
                    style: TextStyle(color: onlineGreen, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.shield_outlined,
                      size: 12, color: secondaryText.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text(
                    "Secure Access",
                    style: TextStyle(
                        color: secondaryText.withOpacity(0.8), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderInput, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          color: textWhite,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        cursorColor: accentOrange,
        cursorWidth: 1.5,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Wajib diisi";
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: secondaryText, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isLoading
              ? const LinearGradient(
                  colors: [accentOrangeDark, accentOrangeDark])
              : const LinearGradient(
                  colors: [accentOrange, accentOrangeDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: accentOrange.withOpacity(0.35),
                    blurRadius: 25,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: accentOrange.withOpacity(0.15),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : login,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.login_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text(
                          "SIGN IN",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== Tombol Pricing Plan =====
  Widget _buildPricingPlanButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _showPricingPlan,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgInput.withOpacity(0.3),
          side: BorderSide(color: accentOrange.withOpacity(0.5), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.diamond_outlined, color: accentOrange, size: 18),
            SizedBox(width: 8),
            Text(
              "Pricing Plan",
              style: TextStyle(
                color: accentOrange,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Baris ikon sosial: Developer / Pemilik / TikTok =====
  Widget _buildSocialRow() {
    Widget socialItem({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: secondaryText.withOpacity(0.9), fontSize: 11),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: accentOrange.withOpacity(0.08),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            socialItem(
              icon: Icons.send_rounded,
              label: "Developer",
              color: accentOrange,
              onTap: () async {
                final url = Uri.parse("https://t.me/Alexandernotdev");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            socialItem(
              icon: Icons.send_rounded,
              label: "Pemilik",
              color: accentOrange,
              onTap: () async {
                final url = Uri.parse("https://t.me/farz_to");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            socialItem(
              icon: Icons.music_note_rounded,
              label: "TikTok",
              color: secondaryText,
              onTap: () async {
                final url = Uri.parse("https://www.tiktok.com/@darkverse");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _OrangeGlowPainter extends CustomPainter {
  final double animValue;
  _OrangeGlowPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFFF9500).withOpacity(0.08 * animValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final paint2 = Paint()
      ..color = const Color(0xFFCC6A00).withOpacity(0.06 * animValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    final paint3 = Paint()
      ..color = const Color(0xFFFFB347).withOpacity(0.04 * animValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    canvas.drawCircle(
        Offset(size.width * 0.3, size.height * 0.05), 150 * animValue, paint1);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.95),
        180 * animValue, paint2);
    canvas.drawCircle(Offset(size.width * -0.1, size.height * 0.5),
        120 * animValue, paint3);
  }

  @override
  bool shouldRepaint(covariant _OrangeGlowPainter oldDelegate) {
    return oldDelegate.animValue != animValue;
  }
}
