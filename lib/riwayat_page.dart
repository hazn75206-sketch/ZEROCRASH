import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RiwayatPage extends StatefulWidget {
  final String sessionKey;
  final String role;

  const RiwayatPage({
    super.key,
    required this.sessionKey,
    required this.role,
  });

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  // === BLACK & RED THEME ===
  static const Color _bgDeep = Color(0xFF000000);
  static const Color _bgCard = Color(0xFF0A0A0A);
  static const Color _bgSection = Color(0xFF050505);
  static const Color _red = Color(0xFFFF0040);
  static const Color _redDark = Color(0xFF8B0020);
  static const Color _border = Color(0xFF1A0A0A);
  static const Color _textMuted = Color(0xFF6B6B6B);
  static const Color _textSubtle = Color(0xFF3D3D3D);

  List<ActivityModel> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    const baseUrl = "https://private-server.banditflow.my.id:2014";

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getMyActivity?key=${widget.sessionKey}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid']) {
          List<dynamic> rawList = data['activities'];

          setState(() {
            activities = rawList.map((item) {
              return ActivityModel(
                type: item['type'] ?? 'system',
                title: item['title'] ?? 'Aktivitas',
                description: item['description'] ?? '-',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    item['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
              );
            }).toList();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        debugPrint("Server Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      setState(() => isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
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
          "Activity History",
          style: TextStyle(
            color: _red,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
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
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _red, strokeWidth: 2.5),
              )
            : activities.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadActivities,
                    color: _red,
                    backgroundColor: _bgCard,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        return _buildActivityCard(activities[index]);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: _red.withValues(alpha: 0.10), width: 2),
                boxShadow: [
                  BoxShadow(color: _red.withValues(alpha: 0.06), blurRadius: 30, spreadRadius: 0),
                ],
              ),
              child: Icon(Icons.history_toggle_off, size: 50, color: _red.withValues(alpha: 0.25)),
            ),
            const SizedBox(height: 28),
            const Text(
              "NO ACTIVITY YET",
              style: TextStyle(
                color: _red,
                fontSize: 16,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Belum ada catatan aktivitas.\nPastikan server aktif.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontFamily: 'ShareTechMono',
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    Color iconColor;
    IconData iconData;
    String typeLabel;
    Color badgeBg;
    Color badgeText;

    switch (activity.type) {
      case 'login':
        iconColor = const Color(0xFF00E676);
        iconData = Icons.login_rounded;
        typeLabel = "LOGIN";
        badgeBg = const Color(0xFF00E676).withValues(alpha: 0.10);
        badgeText = const Color(0xFF00E676);
        break;
      case 'bug':
        iconColor = _red;
        iconData = Icons.bug_report_outlined;
        typeLabel = "ATTACK";
        badgeBg = _red.withValues(alpha: 0.10);
        badgeText = _red;
        break;
      case 'create':
        iconColor = const Color(0xFFFFD700);
        iconData = Icons.person_add_alt_1_rounded;
        typeLabel = "ACCOUNT";
        badgeBg = const Color(0xFFFFD700).withValues(alpha: 0.10);
        badgeText = const Color(0xFFFFD700);
        break;
      default:
        iconColor = _textMuted;
        iconData = Icons.info_outline;
        typeLabel = "SYSTEM";
        badgeBg = _textMuted.withValues(alpha: 0.08);
        badgeText = _textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: iconColor.withValues(alpha: 0.15)),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeText.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  activity.description,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),

                // Timestamp
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: _textSubtle),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(activity.timestamp),
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
        ],
      ),
    );
  }
}

class ActivityModel {
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;

  ActivityModel({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}