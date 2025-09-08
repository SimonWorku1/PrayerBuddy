import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'new_chat_page.dart';
import 'chat_page.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('Sign in to view messages')),
      );
    }
    final chatsQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('memberIds', arrayContains: user.uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(100)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const NewChatPage()));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatsQuery,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No conversations yet'));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chat = docs[index].data() as Map<String, dynamic>;
              final chatId = docs[index].id;
              final title = (chat['title'] ?? '') as String;
              final lastText = (chat['lastMessageText'] ?? '') as String;
              final isGroup = (chat['isGroup'] ?? false) as bool;
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(isGroup ? Icons.groups : Icons.person),
                ),
                title: Text(title.isNotEmpty ? title : 'Conversation'),
                subtitle: Text(
                  lastText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
