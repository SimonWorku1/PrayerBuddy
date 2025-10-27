import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserProfilePage extends StatelessWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = (data['name'] ?? 'User') as String;
          final handle = (data['handle'] ?? '') as String;
          final photoUrl = data['photoUrl'] as String?;
          final verse = (data['favoriteVerse'] ?? '') as String;
          final song = (data['favoriteSong'] ?? '') as String;
          final bio = (data['bio'] ?? '') as String;

          final postsQuery = FirebaseFirestore.instance
              .collection('posts')
              .where('ownerId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(
                        0xFF795548,
                      ).withOpacity(0.15),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 36,
                              color: Color(0xFF795548),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3A3A3A),
                            ),
                          ),
                          if (handle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '@$handle',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8B8B7A),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6C5E55),
                    ),
                  ),
                ],
                if (verse.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showVerseDialog(
                      context,
                      verse,
                      (data['favoriteVerseVersion'] ?? 'NIV') as String,
                    ),
                    child: Row(
                      children: [
                        const Text('📖'),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            verse,
                            style: const TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (song.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('🎵'),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(song, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: postsQuery,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text('Error loading posts: ${snap.error}');
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: Text('No posts yet')),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final p = docs[index].data() as Map<String, dynamic>;
                        return _UserPostTile(data: p);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserPostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _UserPostTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final postType = (data['postType'] ?? 'prayer') as String;
    final title = (data['title'] ?? '') as String;
    final content = (data['content'] ?? '') as String;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  postType == 'prayer'
                      ? Icons.volunteer_activism
                      : Icons.menu_book_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  postType == 'prayer' ? 'Prayer Request' : 'Verse',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(content),
          ],
        ),
      ),
    );
  }
}

Future<void> _showVerseDialog(
  BuildContext context,
  String ref,
  String version,
) async {
  String text = '';
  String usedVersion = version;
  try {
    final upper = version.toUpperCase();

    // Try BibleGateway proxy first (requires Functions to be configured)
    try {
      // Default Functions region uses cloudfunctions.net; if using v2, adjust host accordingly
      const projectId = 'prayerbuddy-6ca4a';
      final uri = Uri.parse(
        'https://us-central1-$projectId.cloudfunctions.net/bibleGatewayPassage',
      ).replace(queryParameters: {'ref': ref, 'version': upper});
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final t = (body['text'] as String? ?? '').trim();
        if (t.isNotEmpty) {
          text = t;
          usedVersion = (body['version'] as String? ?? upper).toUpperCase();
        }
      }
    } catch (_) {}

    // HelloAO Free Use Bible API (no key). Try primary parameter set.
    try {
      final helloUri = Uri.parse(
        'https://bible.helloao.org/api',
      ).replace(queryParameters: {'translation': upper, 'reference': ref});
      final res = await http.get(helloUri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (body.isNotEmpty) {
          // If the response looks like HTML, skip using it so we can
          // fall back to a reliable JSON/text source.
          final looksLikeHtml =
              body.startsWith('<!doctype') ||
              body.startsWith('<!DOCTYPE') ||
              body.startsWith('<html');
          if (!looksLikeHtml) {
            // Try to parse JSON text field, otherwise treat as plain text
            try {
              final obj = json.decode(body);
              if (obj is Map<String, dynamic>) {
                final maybe = (obj['text'] ?? obj['content'] ?? '') as String?;
                if (maybe != null && maybe.trim().isNotEmpty) {
                  text = maybe.trim();
                }
              }
            } catch (_) {
              // Not JSON – assume plain text
              if (text.isEmpty) text = body;
            }
            if (text.isNotEmpty) usedVersion = upper;
          }
        }
      }
    } catch (_) {}

    // Try alternative param name if first attempt failed
    if (text.isEmpty) {
      try {
        final helloUriAlt = Uri.parse(
          'https://bible.helloao.org/api',
        ).replace(queryParameters: {'version': upper, 'reference': ref});
        final res2 = await http
            .get(helloUriAlt)
            .timeout(const Duration(seconds: 8));
        if (res2.statusCode == 200) {
          final body = res2.body.trim();
          if (body.isNotEmpty) {
            final looksLikeHtml =
                body.startsWith('<!doctype') ||
                body.startsWith('<!DOCTYPE') ||
                body.startsWith('<html');
            if (!looksLikeHtml) {
              try {
                final obj = json.decode(body);
                if (obj is Map<String, dynamic>) {
                  final maybe =
                      (obj['text'] ?? obj['content'] ?? '') as String?;
                  if (maybe != null && maybe.trim().isNotEmpty) {
                    text = maybe.trim();
                  }
                }
              } catch (_) {
                if (text.isEmpty) text = body;
              }
              if (text.isNotEmpty) usedVersion = upper;
            }
          }
        }
      } catch (_) {}
    }

    // As a final fallback, use bible-api.com KJV
    if (text.isEmpty) {
      const translationCode = 'kjv';
      final uri = Uri.parse(
        'https://bible-api.com/${Uri.encodeComponent(ref)}?translation=$translationCode',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        if (body['text'] is String &&
            (body['text'] as String).trim().isNotEmpty) {
          text = (body['text'] as String).trim();
          usedVersion = translationCode.toUpperCase();
        } else if (body['verses'] is List) {
          final verses = (body['verses'] as List)
              .map((v) => (v as Map<String, dynamic>)['text'] as String? ?? '')
              .join(' ')
              .trim();
          if (verses.isNotEmpty) {
            text = verses;
            usedVersion = translationCode.toUpperCase();
          }
        }
      }
    }
  } catch (_) {}

  if (text.isEmpty) {
    text = ref;
  }

  // ignore: use_build_context_synchronously
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ref),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            const SizedBox(height: 8),
            Text(
              'Version: $usedVersion',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (usedVersion != version)
              Text(
                'Shown in $usedVersion (requested version unavailable)',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
