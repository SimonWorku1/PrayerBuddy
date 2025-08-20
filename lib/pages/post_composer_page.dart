import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PostComposerPage extends StatefulWidget {
  const PostComposerPage({super.key});

  @override
  State<PostComposerPage> createState() => _PostComposerPageState();
}

class _PostComposerPageState extends State<PostComposerPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _anonymous = false;
  bool _submitting = false;
  String _postType = 'prayer'; // 'prayer' | 'verse'

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      final posts = FirebaseFirestore.instance.collection('posts');
      await posts.add({
        'ownerId': user.uid,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'anonymous': _anonymous,
        'postType': _postType,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': _anonymous ? 'anonymous' : 'public',
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Prayer Request'),
                    selected: _postType == 'prayer',
                    onSelected: (v) {
                      if (v) setState(() => _postType = 'prayer');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Verse on my heart'),
                    selected: _postType == 'verse',
                    onSelected: (v) {
                      if (v) setState(() => _postType = 'verse');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Content is required'
                    : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.mic_none),
                title: const Text('Voice recording (coming soon)'),
                dense: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Post anonymously')),
                  Switch(
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
