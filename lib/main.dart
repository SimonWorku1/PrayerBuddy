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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable testing mode for iOS Simulator to prevent phone auth crashes
  if (kDebugMode) {
    try {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
        phoneNumber: '+15555550100', // Test phone number
        smsCode: '123456', // Test SMS code
      );
    } catch (e) {
      print('Warning: Could not set testing mode: $e');
    }
  }

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
          seedColor: const Color(0xFF6B4EFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5DC),
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
            borderSide: const BorderSide(color: Color(0xFF6B4EFF), width: 2),
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const PrayerBuddyHomePage(),
        '/auth': (context) => const AuthPage(),
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
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5DC),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B4EFF)),
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
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5DC),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B4EFF)),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
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
    const NotificationsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
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
            _buildCenterAddButton(),
            _buildNavItem(3, Icons.public_outlined, Icons.public, 'Explore'),
            _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAddButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PostComposerPage()));
      },
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF6B4EFF),
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
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
          Icon(
            isSelected ? filledIcon : outlineIcon,
            size: 28,
            color: isSelected
                ? const Color(0xFF8B8B7A)
                : const Color(0xFFB8B8A8),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? const Color(0xFF8B8B7A)
                  : const Color(0xFFB8B8A8),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PrayerBuddy',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B8B7A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF8B8B7A)),
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
          child: _tab == 'friends'
              ? const _FriendsFeed()
              : _tab == 'world'
              ? const _WorldFeed()
              : const _AnonymousFeed(),
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
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No posts yet'));
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _PostTile(data: data);
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()..shuffle();
        if (docs.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _PostTile(data: data);
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No anonymous posts yet'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _PostTile(data: data);
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
    final isAnonymous = (data['visibility'] ?? 'public') == 'anonymous';
    final postType = (data['postType'] ?? 'prayer') as String;
    final ownerId = (data['ownerId'] ?? '') as String;
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
                  color: const Color(0xFF6B4EFF),
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
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(ownerId)
                    .get(),
                builder: (context, snap) {
                  final name = snap.hasData && snap.data!.exists
                      ? ((snap.data!.data() as Map<String, dynamic>)['name'] ??
                                'User')
                            as String
                      : 'User';
                  return InkWell(
                    onTap: () {
                      if (ownerId.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfilePage(userId: ownerId),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          child: Icon(Icons.person, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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
          ],
        ),
      ),
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
