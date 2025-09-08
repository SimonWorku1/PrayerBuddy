import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = <String>{};
  bool _searching = false;
  List<QueryDocumentSnapshot> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        setState(() => _searchResults = []);
        return;
      }
      final usersRef = FirebaseFirestore.instance.collection('users');
      final byName = await usersRef
          .where('name', isGreaterThanOrEqualTo: q)
          .limit(10)
          .get();
      final byHandle = await usersRef
          .where('handle', isGreaterThanOrEqualTo: q)
          .limit(10)
          .get();
      final merged = {...byName.docs, ...byHandle.docs}.toList();
      setState(() => _searchResults = merged);
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _createChat() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || _selectedUserIds.isEmpty) return;
    final memberIds = <String>{me.uid, ..._selectedUserIds}.toList()..sort();
    final isGroup = memberIds.length > 2;
    // Title: for group, prompt later; for 1:1, resolve other name lazily
    final chatRef = await FirebaseFirestore.instance.collection('chats').add({
      'memberIds': memberIds,
      'isGroup': isGroup,
      'title': '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': '',
    });
    if (!mounted) return;
    Navigator.of(context).pop(chatRef.id);
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        actions: [
          TextButton(
            onPressed: _selectedUserIds.isEmpty ? null : _createChat,
            child: const Text('Create'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or @handle',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      ),
              ),
              onChanged: (v) => _runSearch(v),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Or pick from friends',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : (_searchController.text.isNotEmpty
                        ? _buildSearchResults()
                        : _buildFriendsList(me?.uid ?? '')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final doc = _searchResults[index];
        final data = doc.data() as Map<String, dynamic>;
        final uid = doc.id;
        final name = (data['name'] ?? 'User') as String;
        final handle = (data['handle'] ?? '') as String;
        final selected = _selectedUserIds.contains(uid);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(name),
          subtitle: handle.isNotEmpty ? Text('@$handle') : null,
          trailing: Checkbox(
            value: selected,
            onChanged: (_) {
              setState(() {
                if (selected) {
                  _selectedUserIds.remove(uid);
                } else {
                  _selectedUserIds.add(uid);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(String myUid) {
    if (myUid.isEmpty) return const SizedBox.shrink();
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .limit(100)
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No friends yet'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final friendId = docs[index].id;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendId)
                  .get(),
              builder: (context, snap) {
                final data = snap.hasData && snap.data!.exists
                    ? snap.data!.data() as Map<String, dynamic>
                    : <String, dynamic>{};
                final name = (data['name'] ?? 'User') as String;
                final handle = (data['handle'] ?? '') as String;
                final selected = _selectedUserIds.contains(friendId);
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name),
                  subtitle: handle.isNotEmpty ? Text('@$handle') : null,
                  trailing: Checkbox(
                    value: selected,
                    onChanged: (_) {
                      setState(() {
                        if (selected) {
                          _selectedUserIds.remove(friendId);
                        } else {
                          _selectedUserIds.add(friendId);
                        }
                      });
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
