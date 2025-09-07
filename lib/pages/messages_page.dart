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
              final result = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const NewChatPage()),
              );
              if (result != null && result.isNotEmpty) {
                if (context.mounted) {
                  // Navigate directly to the created/existing chat
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatPage(chatId: result)),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatsQuery,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading chats: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
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
              String lastText = (chat['lastMessageText'] ?? '') as String;
              final lastType = (chat['lastMessageType'] ?? 'text') as String;
              if (lastType == 'image' &&
                  (lastText.isEmpty || lastText == 'Photo')) {
                lastText = 'Photo';
              }
              final isGroup = (chat['isGroup'] ?? false) as bool;
              final lastMessageAt = chat['lastMessageAt'] as Timestamp?;
              final lastMessageSenderId =
                  (chat['lastMessageSenderId'] ?? '') as String;
              // Unread: compare lastMessageAt to chat['lastReadAt'][myUid]
              final myUid = user.uid;
              final Map<String, dynamic> lastReadAtMap =
                  (chat['lastReadAt'] ?? <String, dynamic>{})
                      as Map<String, dynamic>;
              final myLastRead = lastReadAtMap[myUid] as Timestamp?;
              final hasUnread =
                  lastMessageAt != null &&
                  (myLastRead == null ||
                      lastMessageAt.toDate().isAfter(myLastRead.toDate()));

              Widget subtitleWidget = Text(
                lastText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );

              // Show "Seen" if I sent the last message and other read it
              bool showSeen = false;
              if (lastMessageSenderId == myUid && lastMessageAt != null) {
                // If any other member has lastReadAt >= lastMessageAt
                final members = (chat['memberIds'] ?? []) as List<dynamic>;
                for (final m in members) {
                  if (m == myUid) continue;
                  final ts = lastReadAtMap[m] as Timestamp?;
                  if (ts != null &&
                      !ts.toDate().isBefore(lastMessageAt.toDate())) {
                    showSeen = true;
                    break;
                  }
                }
              }
              if (showSeen) {
                subtitleWidget = Row(
                  children: [
                    const Icon(
                      Icons.done_all,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lastText.isNotEmpty ? lastText : 'Seen',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }

              // Dynamic title for 1:1 chats if title is empty, also emit read on open
              if (!isGroup && title.isEmpty) {
                final members = (chat['memberIds'] ?? []) as List<dynamic>;
                final otherId = members.firstWhere(
                  (id) => id != myUid,
                  orElse: () => '',
                );
                return FutureBuilder<DocumentSnapshot>(
                  future: otherId == ''
                      ? null
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherId as String)
                            .get(),
                  builder: (context, snap) {
                    String displayName = 'Conversation';
                    String photoUrl = '';
                    if (snap.hasData && snap.data!.exists) {
                      final data = snap.data!.data() as Map<String, dynamic>;
                      displayName =
                          (data['name'] ?? data['handle'] ?? 'Conversation')
                              as String;
                      photoUrl = (data['photoUrl'] ?? '') as String;
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        displayName,
                        style: hasUnread
                            ? const TextStyle(fontWeight: FontWeight.w700)
                            : null,
                      ),
                      subtitle: subtitleWidget,
                      trailing: hasUnread
                          ? const CircleAvatar(
                              radius: 5,
                              backgroundColor: Colors.redAccent,
                            )
                          : null,
                      onTap: () {
                        // Mark as read when entering chat
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .set({
                              'lastReadAt': {
                                myUid: FieldValue.serverTimestamp(),
                              },
                            }, SetOptions(merge: true));
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatPage(chatId: chatId),
                          ),
                        );
                      },
                    );
                  },
                );
              }

              return ListTile(
                leading: CircleAvatar(
                  child: Icon(isGroup ? Icons.groups : Icons.person),
                ),
                title: Text(
                  title.isNotEmpty ? title : 'Conversation',
                  style: hasUnread
                      ? const TextStyle(fontWeight: FontWeight.w700)
                      : null,
                ),
                subtitle: subtitleWidget,
                trailing: hasUnread
                    ? const CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.redAccent,
                      )
                    : null,
                onTap: () {
                  FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .set({
                        'lastReadAt': {myUid: FieldValue.serverTimestamp()},
                      }, SetOptions(merge: true));
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
