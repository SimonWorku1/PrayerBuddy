import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFF795548).withOpacity(0.15),
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 56,
                          color: Color(0xFF795548),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF795548),
                  ),
                ),
                if (handle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@$handle',
                    style: const TextStyle(color: Color(0xFF8B8B7A)),
                  ),
                ],
                const SizedBox(height: 20),
                _InfoTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Favorite Verse',
                  value: verse,
                ),
                _InfoTile(
                  icon: Icons.music_note_outlined,
                  title: 'Favorite Worship Song',
                  value: song,
                ),
                _InfoTile(icon: Icons.info_outline, title: 'Bio', value: bio),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF795548)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value),
      ),
    );
  }
}
