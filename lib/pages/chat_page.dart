import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:math';

class ChatPage extends StatefulWidget {
  final String chatId;
  const ChatPage({super.key, required this.chatId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  bool _typing = false;
  DateTime _lastTypingEmit = DateTime.fromMillisecondsSinceEpoch(0);
  XFile? _pendingImage;

  @override
  void dispose() {
    _setTyping(false);
    _controller.dispose();
    super.dispose();
  }

  bool _isEmojiOnly(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    final emojiRegex = RegExp(
      r'^(?:[\p{Emoji_Presentation}\p{Extended_Pictographic}\u200d\uFE0F\s]+)$',
      unicode: true,
    );
    return emojiRegex.hasMatch(text);
  }

  Future<void> _send() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImage == null) return;
    setState(() => _sending = true);
    try {
      if (_pendingImage != null) {
        await _uploadAndSendImage(
          _pendingImage!,
          caption: text.isNotEmpty ? text : null,
        );
        _controller.clear();
        _setTyping(false);
        setState(() => _pendingImage = null);
      } else {
        final msgRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc();
        await msgRef.set({
          'senderId': me.uid,
          'text': text,
          'type': 'text',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .set({
              'lastMessageText': text,
              'lastMessageAt': FieldValue.serverTimestamp(),
              'lastMessageSenderId': me.uid,
              'lastMessageType': 'text',
            }, SetOptions(merge: true));
        _controller.clear();
        _setTyping(false);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() {
      _pendingImage = picked;
    });
  }

  Future<void> _uploadAndSendImage(XFile picked, {String? caption}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    // Prepare content type and bytes once
    final lower = picked.path.toLowerCase();
    final ext = lower.endsWith('.png') ? 'png' : 'jpg';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final bytes = await File(picked.path).readAsBytes();

    // Create message doc first for a stable ID
    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc();

    final randomSuffix = Random().nextInt(0x7fffffff).toRadixString(16);
    final fileName =
        '${msgRef.id}_${DateTime.now().microsecondsSinceEpoch}_$randomSuffix.$ext';
    final ref = FirebaseStorage.instance.ref().child(
      'chats/${widget.chatId}/images/$fileName',
    );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await msgRef.set({
      'senderId': me.uid,
      'imageUrl': url,
      if (caption != null && caption.isNotEmpty) 'text': caption,
      'type': 'image',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .set({
          'lastMessageText': caption?.isNotEmpty == true ? caption : 'Photo',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageSenderId': me.uid,
          'lastMessageType': 'image',
        }, SetOptions(merge: true));
  }

  Future<void> _markRead() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set(
      {
        'lastReadAt': {me.uid: FieldValue.serverTimestamp()},
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _setTyping(bool typing) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    if (typing) {
      final now = DateTime.now();
      if (now.difference(_lastTypingEmit).inMilliseconds < 1500 && _typing) {
        return;
      }
      _lastTypingEmit = now;
    }
    _typing = typing;
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set(
      {
        'typing': {me.uid: typing},
      },
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    final me = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .snapshots(),
          builder: (context, snapshot) {
            String title = 'Chat';
            String typingText = '';
            if (snapshot.hasData && snapshot.data!.exists) {
              final chat = snapshot.data!.data() as Map<String, dynamic>;
              title = (chat['title'] ?? '') as String;
              final members = (chat['memberIds'] ?? []) as List<dynamic>;
              // For 1:1 chats with empty title, show other user's name
              final isGroup = (chat['isGroup'] ?? false) as bool;
              if (!isGroup && (title.isEmpty)) {
                final otherId = members.firstWhere(
                  (id) => id != me?.uid,
                  orElse: () => '',
                );
                if (otherId is String && otherId.isNotEmpty) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(otherId)
                        .get(),
                    builder: (context, snap) {
                      String displayName = 'Chat';
                      if (snap.hasData && snap.data!.exists) {
                        final data = snap.data!.data() as Map<String, dynamic>;
                        displayName =
                            (data['name'] ?? data['handle'] ?? 'Chat')
                                as String;
                      }
                      // typing indicator
                      final typingMap =
                          (chat['typing'] ?? <String, dynamic>{})
                              as Map<String, dynamic>;
                      final othersTyping = typingMap.entries.any(
                        (e) => e.key != me?.uid && e.value == true,
                      );
                      typingText = othersTyping ? 'typing…' : '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(displayName),
                          if (typingText.isNotEmpty)
                            Text(
                              typingText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      );
                    },
                  );
                }
              }
              // typing indicator for group or titled chats
              final typingMap =
                  (chat['typing'] ?? <String, dynamic>{})
                      as Map<String, dynamic>;
              final othersTyping = typingMap.entries.any(
                (e) => e.key != me?.uid && e.value == true,
              );
              typingText = othersTyping ? 'typing…' : '';
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title.isNotEmpty ? title : 'Chat'),
                if (typingText.isNotEmpty)
                  Text(
                    typingText,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Say hello 👋'));
                }
                // Mark as read when messages load
                _markRead();
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == me?.uid;
                    final text = (data['text'] ?? '') as String;
                    final imageUrl = (data['imageUrl'] ?? '') as String;
                    if (imageUrl.isNotEmpty) {
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  imageUrl,
                                  width: 240,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(text),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                    final emojiOnly = _isEmojiOnly(text);
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: emojiOnly ? 8 : 12,
                          vertical: emojiOnly ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Text(
                          text,
                          style: emojiOnly
                              ? const TextStyle(fontSize: 28)
                              : null,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_pendingImage!.path),
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: _pendingImage == null
                                ? 'Message...'
                                : 'Add a caption...',
                          ),
                          onChanged: (v) {
                            if (v.trim().isNotEmpty) {
                              _setTyping(true);
                            } else {
                              _setTyping(false);
                            }
                          },
                          onSubmitted: (_) {
                            if (!_sending) {
                              _send();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_pendingImage != null)
                        IconButton(
                          tooltip: 'Remove image',
                          onPressed: _sending
                              ? null
                              : () => setState(() => _pendingImage = null),
                          icon: const Icon(Icons.close),
                        ),
                      IconButton(
                        tooltip: 'Photo',
                        onPressed: _sending ? null : _pickAndSendImage,
                        icon: const Icon(Icons.photo),
                      ),
                      IconButton(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
