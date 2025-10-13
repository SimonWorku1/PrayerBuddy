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
    final apiBibleKey = const String.fromEnvironment('BIBLE_API_KEY');
    if (apiBibleKey.isNotEmpty) {
      // Resolve a Bible ID for the requested abbreviation (e.g., NIV, ESV, KJV, NKJV, NLT)
      final lookupUri = Uri.parse(
        'https://api.scripture.api.bible/v1/bibles?abbreviation=${Uri.encodeQueryComponent(upper)}',
      );
      final lookupRes = await http
          .get(lookupUri, headers: {'api-key': apiBibleKey})
          .timeout(const Duration(seconds: 8));
      String? bibleId;
      if (lookupRes.statusCode == 200) {
        final body = json.decode(lookupRes.body) as Map<String, dynamic>;
        final list = (body['data'] as List?) ?? const [];
        if (list.isNotEmpty) {
          // Prefer exact abbreviation match; otherwise first result
          final exact = list.cast<Map<String, dynamic>>().firstWhere(
            (b) =>
                (b['abbreviation'] as String?)?.toUpperCase() == upper ||
                (b['abbreviationLocal'] as String?)?.toUpperCase() == upper,
            orElse: () => list.first as Map<String, dynamic>,
          );
          bibleId = exact['id'] as String?;
        }
      }

      // If no specific bible found, try a generic English KJV as a fallback
      if (bibleId == null) {
        final kjvUri = Uri.parse(
          'https://api.scripture.api.bible/v1/bibles?abbreviation=KJV',
        );
        final kjvRes = await http
            .get(kjvUri, headers: {'api-key': apiBibleKey})
            .timeout(const Duration(seconds: 8));
        if (kjvRes.statusCode == 200) {
          final body = json.decode(kjvRes.body) as Map<String, dynamic>;
          final list = (body['data'] as List?) ?? const [];
          if (list.isNotEmpty) {
            bibleId = (list.first as Map<String, dynamic>)['id'] as String?;
            usedVersion = 'KJV';
          }
        }
      }

      if (bibleId != null) {
        final passageUri = Uri.parse(
          'https://api.scripture.api.bible/v1/bibles/$bibleId/passages/'
          '${Uri.encodeComponent(ref)}'
          '?contentType=text'
          '&includeFootnotes=false'
          '&includeHeadings=false'
          '&includeVerseNumbers=false'
          '&includeChapterNumbers=false'
          '&includePassageReferences=false',
        );
        final passageRes = await http
            .get(passageUri, headers: {'api-key': apiBibleKey})
            .timeout(const Duration(seconds: 8));
        if (passageRes.statusCode == 200) {
          final pb = json.decode(passageRes.body) as Map<String, dynamic>;
          final data = pb['data'];
          if (data is Map<String, dynamic>) {
            final content = data['content'];
            if (content is String && content.trim().isNotEmpty) {
              text = content.trim();
              usedVersion = upper;
            } else if (data['passages'] is List) {
              final joined = (data['passages'] as List)
                  .map(
                    (e) =>
                        (e as Map<String, dynamic>)['content'] as String? ?? '',
                  )
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .join('\n\n');
              if (joined.isNotEmpty) {
                text = joined;
                usedVersion = upper;
              }
            }
          }
        }

        // If no text yet, try resolving passage ID via search
        if (text.isEmpty) {
          final searchUri = Uri.parse(
            'https://api.scripture.api.bible/v1/bibles/$bibleId/search'
            '?query=${Uri.encodeQueryComponent(ref)}&limit=3',
          );
          final searchRes = await http
              .get(searchUri, headers: {'api-key': apiBibleKey})
              .timeout(const Duration(seconds: 8));
          if (searchRes.statusCode == 200) {
            final sb = json.decode(searchRes.body) as Map<String, dynamic>;
            final sdata = sb['data'];
            List<String> passageIds = [];
            if (sdata is Map<String, dynamic>) {
              final passages = sdata['passages'];
              final verses = sdata['verses'];
              if (passages is List && passages.isNotEmpty) {
                passageIds = passages
                    .cast<Map<String, dynamic>>()
                    .map((p) => p['id'] as String? ?? '')
                    .where((id) => id.isNotEmpty)
                    .toList();
              } else if (verses is List && verses.isNotEmpty) {
                passageIds = verses
                    .cast<Map<String, dynamic>>()
                    .map(
                      (v) =>
                          v['passageId'] as String? ??
                          (v['id'] as String? ?? ''),
                    )
                    .where((id) => id.isNotEmpty)
                    .toList();
              }
            }

            if (passageIds.isNotEmpty) {
              final resolved = <String>[];
              for (final pid in passageIds) {
                final rUri = Uri.parse(
                  'https://api.scripture.api.bible/v1/bibles/$bibleId/passages/$pid'
                  '?contentType=text&includeFootnotes=false&includeHeadings=false'
                  '&includeVerseNumbers=false&includeChapterNumbers=false&includePassageReferences=false',
                );
                final r = await http
                    .get(rUri, headers: {'api-key': apiBibleKey})
                    .timeout(const Duration(seconds: 8));
                if (r.statusCode == 200) {
                  final rb = json.decode(r.body) as Map<String, dynamic>;
                  final rd = rb['data'];
                  final rc = rd is Map<String, dynamic> ? rd['content'] : null;
                  if (rc is String && rc.trim().isNotEmpty) {
                    resolved.add(rc.trim());
                  }
                }
              }
              if (resolved.isNotEmpty) {
                text = resolved.join('\n\n');
                usedVersion = upper;
              }
            }
          }
        }
      }
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
      content: Column(
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
              const String.fromEnvironment('BIBLE_API_KEY').isEmpty
                  ? 'Shown in KJV (API key not configured)'
                  : 'Shown in $usedVersion (requested version unavailable)',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
        ],
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
