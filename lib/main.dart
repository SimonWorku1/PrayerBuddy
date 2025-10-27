import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/auth_page.dart';
import 'pages/profile_setup_page.dart';
import 'pages/profile_page.dart';
import 'pages/find_friends_page.dart';
import 'pages/post_composer_page.dart';
import 'pages/user_profile_page.dart';
import 'pages/messages_page.dart';
import 'pages/reactivate_page.dart';
import 'pages/chat_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Clear Firestore cache on app startup to prevent deleted posts from showing
  try {
    await FirebaseFirestore.instance.clearPersistence();
  } catch (e) {
    // Cache might be in use, that's okay - it will be cleared on next restart
    print('Could not clear Firestore cache: $e');
  }

  // Removed test phone auth override – real SMS verification will be used

  runApp(const PrayerBuddyApp());
}

class PrayerBuddyApp extends StatelessWidget {
  const PrayerBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrayerBuddy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF795548), // earthy brown
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5DC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C5E55),
          ),
          foregroundColor: Color(0xFF6C5E55),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        chipTheme: ChipThemeData(
          shape: const StadiumBorder(),
          backgroundColor: const Color(0xFF795548).withOpacity(0.08),
          selectedColor: const Color(0xFF795548).withOpacity(0.16),
          labelStyle: const TextStyle(color: Color(0xFF6C5E55)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.linux: ZoomPageTransitionsBuilder(),
            TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          },
        ),
        popupMenuTheme: PopupMenuThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF3A3A3A),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF795548), width: 2),
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const PrayerBuddyHomePage(),
        '/auth': (context) => const AuthPage(),
        '/reactivate': (context) => const ReactivatePage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5DC),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in, check if they have completed profile setup
          return ProfileCheckWrapper(user: snapshot.data!);
        }

        // User is not signed in, show auth page
        return const AuthPage();
      },
    );
  }
}

class ProfileCheckWrapper extends StatelessWidget {
  final User user;

  const ProfileCheckWrapper({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5DC),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          // If deactivated, prompt reactivation
          if ((data['isDeactivated'] ?? false) == true) {
            return const ReactivatePage();
          }
          // User profile exists, show main app
          return const PrayerBuddyHomePage();
        } else {
          // User profile doesn't exist, show profile setup
          return ProfileSetupPage(user: user);
        }
      },
    );
  }
}

class PrayerBuddyHomePage extends StatefulWidget {
  const PrayerBuddyHomePage({super.key});

  @override
  State<PrayerBuddyHomePage> createState() => _PrayerBuddyHomePageState();
}

class _PrayerBuddyHomePageState extends State<PrayerBuddyHomePage> {
  int _selectedIndex = 0;
  // final AuthService _authService = AuthService(); // Commented out temporarily

  final List<Widget> _pages = [
    const HomeFeedPage(),
    const FindFriendsPage(),
    const SizedBox.shrink(),
    const MessagesPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Redirect active session to reactivation page if necessary
    final me = FirebaseAuth.instance.currentUser;
    if (me != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(me.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data() as Map<String, dynamic>;
            if ((data['isDeactivated'] ?? false) == true) {
              return const ReactivatePage();
            }
          }
          return _buildScaffold(context);
        },
      );
    }
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final inFromRight = Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: inFromRight, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
            _buildNavItem(1, Icons.group_outlined, Icons.group, 'Friends'),
            _buildCenterJoinButton(),
            _buildNavItem(3, Icons.mail_outline, Icons.mail, 'Messages'),
            _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterJoinButton() {
    return Transform.translate(
      offset: const Offset(0, -6), // raise hitbox slightly above home indicator
      child: GestureDetector(
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PostComposerPage()));
        },
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF795548),
          ),
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: isSelected ? 1.1 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(
                  isSelected ? filledIcon : outlineIcon,
                  size: 28,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeFeedPage extends StatelessWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'Please sign in',
            style: TextStyle(fontSize: 18, color: Color(0xFF8B8B7A)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'PrayerBuddy',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: const _FeedSwitcher(),
    );
  }
}

class _FeedSwitcher extends StatefulWidget {
  const _FeedSwitcher();

  @override
  State<_FeedSwitcher> createState() => _FeedSwitcherState();
}

class _FeedSwitcherState extends State<_FeedSwitcher> {
  String _tab = 'friends'; // friends | world | anonymous

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'friends',
                label: Text('Friends'),
                icon: Icon(Icons.group),
              ),
              ButtonSegment(
                value: 'world',
                label: Text('World'),
                icon: Icon(Icons.public),
              ),
              ButtonSegment(
                value: 'anonymous',
                label: Text('Anonymous'),
                icon: Icon(Icons.visibility_off),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<String>(_tab),
              child: _tab == 'friends'
                  ? const _FriendsFeed()
                  : _tab == 'world'
                  ? const _WorldFeed()
                  : const _AnonymousFeed(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendsFeed extends StatelessWidget {
  const _FriendsFeed();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .limit(10)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final friendIds = snap.data!.docs.map((d) => d.id).toList();
        if (friendIds.isEmpty) {
          return const Center(child: Text('Add friends to see their posts'));
        }
        final posts = FirebaseFirestore.instance
            .collection('posts')
            .where('visibility', isEqualTo: 'public')
            .where('ownerId', whereIn: friendIds)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots();
        return StreamBuilder<QuerySnapshot>(
          stream: posts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading posts: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            // Filter out hidden posts and posts from deactivated users
            final visibleDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isHidden'] != true && data['ownerActive'] != false;
            }).toList();

            if (visibleDocs.isEmpty) {
              return const Center(child: Text('No posts yet'));
            }
            return ListView.builder(
              itemCount: visibleDocs.length,
              itemBuilder: (context, index) {
                final doc = visibleDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                // Validate post data before rendering
                if (data['content'] == null ||
                    data['content'].toString().isEmpty) {
                  return const SizedBox.shrink(); // Skip invalid posts
                }
                return _PostTile(data: {...data, 'id': doc.id});
              },
            );
          },
        );
      },
    );
  }
}

class _WorldFeed extends StatelessWidget {
  const _WorldFeed();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()..shuffle();
        // Filter out hidden posts and posts from deactivated users
        final visibleDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isHidden'] != true && data['ownerActive'] != false;
        }).toList();

        if (visibleDocs.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }
        return ListView.builder(
          itemCount: visibleDocs.length,
          itemBuilder: (context, index) {
            final doc = visibleDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            // Validate post data before rendering
            if (data['content'] == null || data['content'].toString().isEmpty) {
              return const SizedBox.shrink(); // Skip invalid posts
            }
            return _PostTile(data: {...data, 'id': doc.id});
          },
        );
      },
    );
  }
}

class _AnonymousFeed extends StatelessWidget {
  const _AnonymousFeed();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('visibility', isEqualTo: 'anonymous')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        // Filter out hidden posts and posts from deactivated users
        final visibleDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isHidden'] != true && data['ownerActive'] != false;
        }).toList();

        if (visibleDocs.isEmpty) {
          return const Center(child: Text('No anonymous posts yet'));
        }
        return ListView.builder(
          itemCount: visibleDocs.length,
          itemBuilder: (context, index) {
            final doc = visibleDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            // Validate post data before rendering
            if (data['content'] == null || data['content'].toString().isEmpty) {
              return const SizedBox.shrink(); // Skip invalid posts
            }
            return _PostTile(data: {...data, 'id': doc.id});
          },
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PostTile({required this.data});

  @override
  Widget build(BuildContext context) {
    // Validate that we have essential post data
    if (data['content'] == null || data['content'].toString().isEmpty) {
      return const SizedBox.shrink(); // Don't render invalid posts
    }

    final isAnonymous = (data['visibility'] ?? 'public') == 'anonymous';
    final postType = (data['postType'] ?? 'prayer') as String;
    final ownerId = (data['ownerId'] ?? '') as String;
    final ownerNameInline = (data['ownerName'] ?? '') as String;
    final ownerHandleInline = (data['ownerHandle'] ?? '') as String;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  postType == 'prayer' ? 'Prayer Request' : 'Verse',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (isAnonymous)
                  const Icon(
                    Icons.visibility_off,
                    size: 16,
                    color: Colors.grey,
                  ),
              ],
            ),
            if (!isAnonymous && ownerId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  // Always resolve latest user display fields on render so updates show
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(ownerId)
                        .get(),
                    builder: (context, snap) {
                      // Handle error case - if user doesn't exist, show fallback
                      if (snap.hasError) {
                        return _buildUserRow(
                          context: context,
                          name: ownerNameInline.isNotEmpty
                              ? ownerNameInline
                              : 'User',
                          handle: ownerHandleInline,
                          photo: '',
                          ownerId: ownerId,
                        );
                      }

                      final name = snap.hasData && snap.data!.exists
                          ? ((snap.data!.data()
                                        as Map<String, dynamic>)['name'] ??
                                    'User')
                                as String
                          : (ownerNameInline.isNotEmpty
                                ? ownerNameInline
                                : 'User');
                      final handle = snap.hasData && snap.data!.exists
                          ? ((snap.data!.data()
                                        as Map<String, dynamic>)['handle'] ??
                                    '')
                                as String
                          : ownerHandleInline;
                      final photo = snap.hasData && snap.data!.exists
                          ? ((snap.data!.data()
                                        as Map<String, dynamic>)['photoUrl'] ??
                                    '')
                                as String
                          : '';

                      return _buildUserRow(
                        context: context,
                        name: name,
                        handle: handle,
                        photo: photo,
                        ownerId: ownerId,
                      );
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
            if ((data['title'] ?? '').toString().isNotEmpty)
              Text(
                data['title'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 6),
            Text((data['content'] ?? '') as String),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    final postId =
                        (data['id'] ?? (data['__id'] ?? '')) as String;
                    final post = {...data, 'id': postId};
                    if (postId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post unavailable')),
                      );
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (ctx) => _ReplySheet(post: post),
                    );
                  },
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    final postId =
                        (data['id'] ?? (data['__id'] ?? '')) as String;
                    final post = {...data, 'id': postId};
                    if (postId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post unavailable')),
                      );
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (ctx) =>
                          _CommentsSheet(postId: postId, post: post),
                    );
                  },
                  child: const Text(
                    'Show replies',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow({
    required BuildContext context,
    required String name,
    required String handle,
    required String photo,
    required String ownerId,
  }) {
    return InkWell(
      onTap: () {
        if (ownerId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => UserProfilePage(userId: ownerId)),
          );
        }
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty ? const Icon(Icons.person, size: 14) : null,
          ),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (handle.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text('@$handle', style: const TextStyle(color: Colors.grey)),
          ],
          const Spacer(),
          _FriendAction(ownerId: ownerId),
        ],
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  final Map<String, dynamic> post;
  const _ReplySheet({required this.post});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final postId = (widget.post['id'] ?? '') as String;
      if (postId.isEmpty) {
        throw Exception('postId missing');
      }
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add({
            'authorId': me.uid,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendDm() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final ownerId = (widget.post['ownerId'] ?? '') as String;
    if (ownerId.isEmpty || ownerId == me.uid) return;
    final memberIds = [me.uid, ownerId]..sort();
    final memberKey = memberIds.join('_');
    final chatDoc = FirebaseFirestore.instance
        .collection('chats')
        .doc(memberKey);
    await chatDoc.set({
      'memberIds': memberIds,
      'memberKey': memberKey,
      'isGroup': false,
      'title': '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': '',
      'lastMessageType': 'text',
    }, SetOptions(merge: true));

    final replyText = _controller.text.trim();
    final msgRef = chatDoc.collection('messages').doc();
    await msgRef.set({
      'senderId': me.uid,
      'type': 'post_reply',
      'text': replyText,
      'post': {
        'id': widget.post['id'] ?? '',
        'ownerId': widget.post['ownerId'] ?? '',
        'title': widget.post['title'] ?? '',
        'content': widget.post['content'] ?? '',
        'visibility': widget.post['visibility'] ?? 'public',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    await chatDoc.set({
      'lastMessageText': replyText.isNotEmpty
          ? replyText
          : 'Replied to your post',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': me.uid,
      'lastMessageType': 'post_reply',
    }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatPage(chatId: chatDoc.id)));
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.post['title'] ?? '') as String;
    final content = (widget.post['content'] ?? '') as String;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reply to post', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 4),
                Text(content, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Write a reply…'),
            minLines: 1,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _sending ? null : _sendComment,
                icon: const Icon(Icons.forum, size: 16),
                label: const Text('Comment'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _sending ? null : _sendDm,
                icon: const Icon(Icons.mail_outline, size: 16),
                label: const Text('DM privately'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> post;
  const _CommentsSheet({required this.postId, required this.post});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
    final title = (post['title'] ?? '') as String;
    final content = (post['content'] ?? '') as String;
    final ownerId = (post['ownerId'] ?? '') as String;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 6),
                Text(content),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 220,
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: Text('No comments on this post')),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final c = docs[index].data() as Map<String, dynamic>;
                    final text = (c['text'] ?? '') as String;
                    final authorId = (c['authorId'] ?? '') as String;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(authorId)
                            .get(),
                        builder: (context, snap) {
                          final name = snap.hasData && snap.data!.exists
                              ? ((snap.data!.data()
                                            as Map<String, dynamic>)['name'] ??
                                        'User')
                                    as String
                              : 'User';
                          final isAuthor = ownerId == authorId;
                          return Row(
                            children: [
                              Text(name),
                              if (isAuthor) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'author',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      subtitle: Text(text),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendAction extends StatelessWidget {
  final String ownerId;
  const _FriendAction({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == ownerId) {
      return const SizedBox.shrink();
    }
    final myFriends = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .doc(ownerId)
        .snapshots();
    return StreamBuilder<DocumentSnapshot>(
      stream: myFriends,
      builder: (context, snap) {
        final isFriend = snap.hasData && snap.data!.exists;
        if (isFriend) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF795548).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, size: 14, color: Color(0xFF795548)),
                SizedBox(width: 4),
                Text('Friends', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }
        return TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () async {
            final uid = currentUser.uid;
            await FirebaseFirestore.instance
                .collection('friend_requests')
                .doc('${uid}_$ownerId')
                .set({
                  'from': uid,
                  'to': ownerId,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Request sent')));
            }
          },
          icon: const Icon(Icons.person_add_alt_1, size: 16),
          label: const Text('Add', style: TextStyle(fontSize: 12)),
        );
      },
    );
  }
}

class PrayerRequestsPage extends StatelessWidget {
  const PrayerRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Prayer Requests',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B8B7A),
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Share and support prayer requests',
          style: TextStyle(fontSize: 18, color: Color(0xFF8B8B7A)),
        ),
      ),
    );
  }
}

class AddPrayerPage extends StatelessWidget {
  const AddPrayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Share Prayer Request',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B8B7A),
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Share your prayer needs with the community',
          style: TextStyle(fontSize: 18, color: Color(0xFF8B8B7A)),
        ),
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B8B7A),
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Stay updated with prayer requests and support',
          style: TextStyle(fontSize: 18, color: Color(0xFF8B8B7A)),
        ),
      ),
    );
  }
}

// Profile UI is implemented in pages/profile_page.dart
