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
        .where('isHidden', isEqualTo: false)
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
              final result = await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const NewChatPage()));
              if (result is String && result.isNotEmpty) {
                // Navigate directly to the newly created (or existing) chat
                // ignore: use_build_context_synchronously
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatPage(chatId: result)),
                );
              }
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
              final lastText = (chat['lastMessageText'] ?? '') as String;
              // final isGroup = (chat['isGroup'] ?? false) as bool;

              return Dismissible(
                key: Key(chatId),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  // Handle chat deletion
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                child: Column(
                  children: [
                    FutureBuilder<String>(
                      future: getChatTitleAndValidate(chat, user.uid, chatId),
                      builder: (context, snapshot) {
                        final title = snapshot.data ?? 'User';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: chat['photoUrl'] != null
                                ? NetworkImage(chat['photoUrl'])
                                : null,
                            child: chat['photoUrl'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(title),
                          subtitle: Text(
                            lastText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatPage(chatId: chatId),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    Divider(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper function to get chat title and delete chat if user doesn't exist
  Future<String> getChatTitleAndValidate(
    Map<String, dynamic> chat,
    String currentUserId,
    String chatId,
  ) async {
    if (chat['isGroup'] == true) {
      return chat['title'] ?? 'Group Conversation';
    }
    final memberIds = List<String>.from(chat['memberIds'] ?? []);
    final otherMemberId = memberIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherMemberId.isEmpty) return 'User';

    // Fetch the user's name from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherMemberId)
        .get();
    if (!userDoc.exists) {
      // Delete the chat if the user doesn't exist
      await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
      return 'User';
    }
    return userDoc.data()?['name'] ?? 'User';
  }
}
