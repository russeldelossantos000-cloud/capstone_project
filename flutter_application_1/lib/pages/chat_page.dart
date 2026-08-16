import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/auth_service.dart';
import '../services/firebase_messaging_service.dart';


class ChatPage extends StatefulWidget {
 
  final bool isShopChat;

  const ChatPage({super.key, this.isShopChat = true});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool    _sending  = false;
  int?    _myUserId;
  String? _myName;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (user == null || !mounted) return;

    // FIX: safe int extraction — JSON round-trip can turn int into String
    final id = int.tryParse(user['id'].toString());
    setState(() {
      _myUserId = id;
      final fn  = user['first_name']?.toString() ?? '';
      final ln  = user['last_name']?.toString()  ?? '';
      _myName   = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'User';
    });

    // Mark existing messages as read 
    if (id != null) {
      FirebaseMessagingService.markReadByUser(id);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _myUserId == null) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await FirebaseMessagingService.sendAsUser(
        userId:   _myUserId!,
        userName: _myName ?? 'User',
        text:     text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red,
        ));
        _controller.text = text; // restore so user doesn't lose their message
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('h:mm a').format(ts.toDate());
  }

  String _formatDateLabel(Timestamp? ts) {
    if (ts == null) return '';
    final dt   = ts.toDate();
    final now  = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d, y').format(dt);
  }

  // FIX: safe is_read check — handles int (0/1) or bool from Firestore
  bool _isRead(dynamic value) {
    if (value is bool)   return value;
    if (value is int)    return value != 0;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
      
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryGlow,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.directions_bike_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ShopInfo.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis),
              const Text(ShopInfo.tagline,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.success,
                    overflow: TextOverflow.ellipsis,
                  )),
            ],
          ),
        ]),
      ),
      body: _myUserId == null
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2))
          : Column(children: [
              // ── Message list ──────────────────────────────────────
              Expanded(child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseMessagingService.messagesStream(_myUserId!),
                builder: (context, snap) {

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2));
                  }

                  if (snap.hasError) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ));
                  }

                  final docs = snap.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.waving_hand_outlined,
                            color: AppColors.textMuted, size: 40),
                        const SizedBox(height: 12),
                        // FIX: was \${widget.otherName} — escaped $ printed literally
                        Text('Send a message to ${ShopInfo.name}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 14)),
                      ],
                    ));
                  }

                  
                  SchedulerBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());
                  FirebaseMessagingService.markReadByUser(_myUserId!);

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data    = docs[i].data() as Map<String, dynamic>;
                      final isUser  = data['sender'] == 'user';
                      final text    = data['text']?.toString() ?? '';
                      final ts      = data['timestamp'] as Timestamp?;
                      final isRead  = _isRead(data['is_read']);

                      final showDate = i == 0 || _formatDateLabel(
                        (docs[i - 1].data() as Map<String, dynamic>)['timestamp']
                            as Timestamp?,
                      ) != _formatDateLabel(ts);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Date separator
                          if (showDate) Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(children: [
                              const Expanded(
                                  child: Divider(color: AppColors.divider)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(_formatDateLabel(ts),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                              const Expanded(
                                  child: Divider(color: AppColors.divider)),
                            ]),
                          ),

                          // Message bubble
                          Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isUser) ...[
                                  Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGlow,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.directions_bike_rounded,
                                        color: AppColors.primary, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(child: Column(
                                  crossAxisAlignment: isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context)
                                                .size.width * 0.68,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? AppColors.primary
                                            : AppColors.card,
                                        borderRadius: BorderRadius.only(
                                          topLeft:
                                              const Radius.circular(18),
                                          topRight:
                                              const Radius.circular(18),
                                          bottomLeft:
                                              Radius.circular(isUser ? 18 : 4),
                                          bottomRight:
                                              Radius.circular(isUser ? 4 : 18),
                                        ),
                                        border: isUser
                                            ? null
                                            : Border.all(
                                                color: AppColors.cardBorder),
                                      ),
                                      child: Text(text,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isUser
                                                ? Colors.black
                                                : AppColors.textPrimary,
                                            height: 1.4,
                                          )),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_formatTime(ts),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textMuted,
                                              )),
                                          if (isUser) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              isRead
                                                  ? Icons.done_all_rounded
                                                  : Icons.done_rounded,
                                              size: 12,
                                              color: isRead
                                                  ? AppColors.primary
                                                  : AppColors.textMuted,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                )),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              )),

              // ── Input bar ─────────────────────────────────────────
              Container(
                padding: EdgeInsets.only(
                  left: 16, right: 12,
                  top: 10,
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                      top: BorderSide(color: AppColors.divider, width: 1)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: _sending
                            ? AppColors.primary.withOpacity(0.5)
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.black, size: 20),
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }
}