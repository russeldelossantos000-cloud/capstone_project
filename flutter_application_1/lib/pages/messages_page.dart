import 'package:flutter/material.dart';
import 'chat_page.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatPage(
      
      isShopChat: true,
    );
  }
}