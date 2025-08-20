import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _verseController = TextEditingController();
  final TextEditingController _songController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();
  bool _loading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _nameController.text = (data['name'] ?? '') as String;
      _verseController.text = (data['favoriteVerse'] ?? '') as String;
      _songController.text = (data['favoriteSong'] ?? '') as String;
      _bioController.text = (data['bio'] ?? '') as String;
      _handleController.text = (data['handle'] ?? '') as String;
      _photoUrl = data['photoUrl'] as String?;
    });
  }

  String _sanitizeHandle(String raw) {
    return raw.trim().toLowerCase();
  }

  Future<void> _claimHandleIfChanged() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newRaw = _handleController.text;
    final newHandle = _sanitizeHandle(newRaw);
    // If empty, skip (user chooses no handle)
    if (newHandle.isEmpty) return;
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(newHandle)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Handle must be 3-20 chars: a-z, 0-9, _')),
      );
      throw Exception('invalid handle');
    }

    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final handleRef = db.collection('handles').doc(newHandle);

    await db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() as Map<String, dynamic>? ?? {};
      final currentHandle = (userData['handle'] ?? '') as String;

      // If unchanged, nothing to do
      if (currentHandle == newHandle) return;

      // Check cooldown (30 days)
      final lastUpdated = userData['handleUpdatedAt'];
      if (lastUpdated != null && lastUpdated is Timestamp) {
        final nextAllowed = lastUpdated.toDate().add(const Duration(days: 30));
        if (DateTime.now().isBefore(nextAllowed)) {
          throw Exception(
            'You can change your @ again on ${nextAllowed.toLocal()}',
          );
        }
      }

      // Ensure target handle is free
      final hSnap = await tx.get(handleRef);
      if (hSnap.exists) {
        final hData = hSnap.data() as Map<String, dynamic>;
        if (hData['uid'] != user.uid) {
          throw Exception('This @handle is already taken');
        }
        // If doc exists and owned by user, it's effectively same; but since currentHandle != newHandle, user had a different one before; allow proceed
      }

      // Reserve new handle
      tx.set(handleRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Release old handle if present
      if (currentHandle.isNotEmpty) {
        final oldRef = db.collection('handles').doc(currentHandle);
        tx.delete(oldRef);
      }

      // Update user doc
      tx.set(userRef, {
        'handle': newHandle,
        'handleUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _loading = true);
    try {
      final file = File(picked.path);
      final storage = FirebaseStorage.instanceFor(
        bucket: DefaultFirebaseOptions.currentPlatform.storageBucket,
      );
      final storageRef = storage.ref().child('users/${user.uid}/profile.jpg');
      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() => _photoUrl = url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      // Attempt to claim handle first (may throw)
      await _claimHandleIfChanged();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'favoriteVerse': _verseController.text.trim(),
        'favoriteSong': _songController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF8B8B7A)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: const Color(
                        0xFF6B4EFF,
                      ).withOpacity(0.15),
                      backgroundImage: _photoUrl != null
                          ? NetworkImage(_photoUrl!)
                          : null,
                      child: _photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 56,
                              color: Color(0xFF6B4EFF),
                            )
                          : null,
                    ),
                    PopupMenuButton<String>(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) {
                        if (value == 'camera') {
                          _pickImage(ImageSource.camera);
                        } else {
                          _pickImage(ImageSource.gallery);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'camera',
                          child: Text(
                            'Take photo',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'gallery',
                          child: Text(
                            'Choose from library',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4EFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _handleController,
                decoration: const InputDecoration(
                  labelText: 'Handle (@username)',
                  hintText: 'e.g. @john_doe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _verseController,
                decoration: const InputDecoration(
                  labelText: 'Favorite Bible Verse',
                  hintText: 'e.g. John 3:16',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _songController,
                decoration: const InputDecoration(
                  labelText: 'Favorite Worship Song',
                  hintText: 'e.g. Way Maker',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.music_note_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Share a bit about your faith journey...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
