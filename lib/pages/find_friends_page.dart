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
  bool _showingFriends = true;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Default view shows friends; no extra work required here because we'll
    // render directly from a StreamBuilder.
  }

  Future<void> _search() async {
    final q = _queryController.text.trim().toLowerCase();
    setState(() => _loading = true);
    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final List<DocumentSnapshot> out = [];
      if (q.isEmpty) {
        // Empty query switches back to friends view
        if (mounted) setState(() => _showingFriends = true);
        return;
      } else {
        if (mounted) setState(() => _showingFriends = false);
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
            color: Color(0xFF6C5E55),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Friend requests',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.group_add_outlined, color: Color(0xFF8B8B7A)),
                // Notification dot if there are pending incoming requests
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseAuth.instance.currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('friend_requests')
                            .where(
                              'to',
                              isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                            )
                            .where('status', isEqualTo: 'pending')
                            .limit(1)
                            .snapshots(),
                  builder: (context, snap) {
                    final hasPending =
                        snap.hasData && snap.data!.docs.isNotEmpty;
                    return hasPending
                        ? const Positioned(
                            right: -2,
                            top: -2,
                            child: CircleAvatar(
                              radius: 5,
                              backgroundColor: Color(0xFF795548),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ],
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Sign in to view requests'),
                    );
                  }
                  final stream = FirebaseFirestore.instance
                      .collection('friend_requests')
                      .where('to', isEqualTo: user.uid)
                      .where('status', isEqualTo: 'pending')
                      // Avoid orderBy to prevent index dependency and potential wait states
                      .limit(50)
                      .snapshots();
                  return StreamBuilder<QuerySnapshot>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return SizedBox(
                          height: 200,
                          child: Center(
                            child: Text('Error: ${snapshot.error}'),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final reqs = snapshot.data!.docs;
                      if (reqs.isEmpty) {
                        return const SizedBox(
                          height: 200,
                          child: Center(child: Text('No pending requests')),
                        );
                      }
                      return SizedBox(
                        height: 400,
                        child: ListView.builder(
                          itemCount: reqs.length,
                          itemBuilder: (context, index) {
                            final r =
                                reqs[index].data() as Map<String, dynamic>;
                            final fromId = (r['from'] ?? '') as String;
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(fromId)
                                    .get(),
                                builder: (context, snap) {
                                  final name = snap.hasData && snap.data!.exists
                                      ? ((snap.data!.data()
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >)['name'] ??
                                                'User')
                                            as String
                                      : 'User';
                                  final handle =
                                      snap.hasData && snap.data!.exists
                                      ? ((snap.data!.data()
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >)['handle'] ??
                                                '')
                                            as String
                                      : '';
                                  return Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (handle.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '@$handle',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Accept',
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                    onPressed: () async {
                                      final batch = FirebaseFirestore.instance
                                          .batch();
                                      // add to each other's friends subcollection
                                      batch.set(
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .collection('friends')
                                            .doc(fromId),
                                        {'since': FieldValue.serverTimestamp()},
                                      );
                                      batch.set(
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(fromId)
                                            .collection('friends')
                                            .doc(user.uid),
                                        {'since': FieldValue.serverTimestamp()},
                                      );
                                      // mark request accepted
                                      batch.update(reqs[index].reference, {
                                        'status': 'accepted',
                                      });
                                      await batch.commit();
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Decline',
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await reqs[index].reference.update({
                                        'status': 'declined',
                                      });
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
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
                    setState(() {
                      _showingFriends = true;
                      _results = [];
                    });
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
              child: _showingFriends
                  ? _FriendsList()
                  : (_results.isEmpty
                        ? const Center(
                            child: Text(
                              'No results',
                              style: TextStyle(color: Color(0xFF8B8B7A)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final data =
                                  _results[index].data()
                                      as Map<String, dynamic>;
                              final uid = _results[index].id;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: data['photoUrl'] != null
                                      ? NetworkImage(data['photoUrl'])
                                      : null,
                                  child: data['photoUrl'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(data['name'] ?? 'Unknown'),
                                subtitle: Text(
                                  data['email'] ?? data['phone'] ?? '',
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _sendFriendRequest(uid),
                                  child: const Text('Add'),
                                ),
                              );
                            },
                          )),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnap) {
        final user = userSnap.data;
        if (user == null) {
          return const SizedBox.shrink();
        }
        final stream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('friends')
            .snapshots();
        return StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final currentUid = user.uid;
            final docs = snapshot.data!.docs
                .where((d) => d.id != currentUid)
                .toList(growable: false);
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No friends yet. Search to add some!',
                  style: TextStyle(color: Color(0xFF8B8B7A)),
                ),
              );
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
                    if ((data['isPlaceholder'] ?? false) == true) {
                      return const SizedBox.shrink();
                    }
                    final name = (data['name'] ?? 'User') as String;
                    final handle = (data['handle'] ?? '') as String;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(name),
                      subtitle: handle.isNotEmpty ? Text('@$handle') : null,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
