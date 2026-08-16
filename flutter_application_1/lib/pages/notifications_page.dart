import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
        _notifs = (data['notifications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  IconData _icon(String type) => switch (type) {
    'order_status' => Icons.receipt_long_outlined,
    'new_message'  => Icons.chat_bubble_outline_rounded,
    _              => Icons.notifications_outlined,
  };

  Color _iconColor(String type) => switch (type) {
    'order_status' => AppColors.primary,
    'new_message'  => AppColors.info,
    _              => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_notifs.any((n) => n['is_read'] != 1))
            TextButton(
              onPressed: () async {
                await ApiService.markAllNotificationsRead();
                _load();
              },
              child: const Text("Mark all read", style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _notifs.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_none_rounded, color: AppColors.textMuted, size: 64),
                  SizedBox(height: 12),
                  Text("No notifications yet", style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                ]))
              : RefreshIndicator(
                  color: AppColors.primary, backgroundColor: AppColors.card,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _notifCard(_notifs[i]),
                  ),
                ),
    );
  }

  Widget _notifCard(Map<String, dynamic> n) {
    final isRead = n['is_read'] == 1 || n['is_read'] == true;
    final type   = (n['type'] ?? '').toString();
    String dateStr = '';
    try { dateStr = DateFormat('MMM d · h:mm a').format(DateTime.parse(n['created_at'].toString())); } catch (_) {}

    return GestureDetector(
      onTap: () async {
        if (!isRead) {
          await ApiService.markNotificationRead(n['id'] as int);
          setState(() => n['is_read'] = 1);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppColors.card : AppColors.primaryGlow.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRead ? AppColors.cardBorder : AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _iconColor(type).withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(_icon(type), color: _iconColor(type), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n['title']?.toString() ?? '', style: TextStyle(fontSize: 14, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(n['message']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ])),
          if (!isRead) Container(
            width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
        ]),
      ),
    );
  }
}