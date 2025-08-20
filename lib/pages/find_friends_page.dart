import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  State<FindFriendsPage> createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  final TextEditingController _queryController = TextEditingController();
  bool _loading = false;
  List<DocumentSnapshot> _results = [];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryController.text.trim().toLowerCase();
    setState(() => _loading = true);
    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final List<DocumentSnapshot> out = [];
      if (q.isEmpty) {
        final snap = await usersRef.limit(25).get();
        out.addAll(snap.docs);
      } else {
        final nameSnap = await usersRef
            .where('name', isGreaterThanOrEqualTo: q)
            .limit(10)
            .get();
        final emailSnap = await usersRef
            .where('email', isEqualTo: q)
            .limit(10)
            .get();
        final phoneSnap = await usersRef
            .where('phone', isEqualTo: q)
            .limit(10)
            .get();
        out.addAll({...nameSnap.docs, ...emailSnap.docs, ...phoneSnap.docs});
      }
      if (mounted) setState(() => _results = out);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final reqRef = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc('${user.uid}_$targetUserId');
    await reqRef.set({
      'from': user.uid,
      'to': targetUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Friend request sent')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Find Friends',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B8B7A),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _queryController.clear();
                    _search();
                  },
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _search,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text(
                        'Suggested friends will appear here',
                        style: TextStyle(color: Color(0xFF8B8B7A)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final data =
                            _results[index].data() as Map<String, dynamic>;
                        final uid = _results[index].id;
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(data['name'] ?? 'Unknown'),
                          subtitle: Text(data['email'] ?? data['phone'] ?? ''),
                          trailing: ElevatedButton(
                            onPressed: () => _sendFriendRequest(uid),
                            child: const Text('Add'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}



