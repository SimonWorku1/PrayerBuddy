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
            _buildCenterAddButton(),
            _buildNavItem(3, Icons.mail_outline, Icons.mail, 'Messages'),
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
          color: Color(0xFF795548),
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
    final friendsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .limit(10)
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: friendsStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const _PostSkeletonList();
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
              return const _PostSkeletonList();
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No posts yet!'));
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
          return const _PostSkeletonList();
        }
        final docs = snapshot.data!.docs.toList()..shuffle();
        if (docs.isEmpty) {
          return const Center(child: Text('No posts yet!'));
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
          return const _PostSkeletonList();
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No posts yet!'));
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

class _PostSkeletonList extends StatelessWidget {
  const _PostSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => const _PostSkeletonTile(),
    );
  }
}

class _PostSkeletonTile extends StatelessWidget {
  const _PostSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShimmerBox(width: 140, height: 14),
            SizedBox(height: 12),
            _ShimmerBox(width: double.infinity, height: 12),
            SizedBox(height: 8),
            _ShimmerBox(width: double.infinity, height: 12),
            SizedBox(height: 8),
            _ShimmerBox(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.shade300;
    final highlightColor = Colors.grey.shade100;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            final width = rect.width;
            final gradientWidth = width / 2;
            final dx =
                (width + gradientWidth) * _controller.value - gradientWidth;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.35, 0.5, 0.65],
              transform: GradientTranslation(dx),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }
}

class GradientTranslation extends GradientTransform {
  final double dx;
  const GradientTranslation(this.dx);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()..translate(dx);
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
                      return InkWell(
                        onTap: () {
                          if (ownerId.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfilePage(userId: ownerId),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: photo.isNotEmpty
                                  ? NetworkImage(photo)
                                  : null,
                              child: photo.isEmpty
                                  ? const Icon(Icons.person, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 8),
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
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                            const Spacer(),
                            _FriendAction(ownerId: ownerId),
                          ],
                        ),
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
          ],
        ),
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
          return Chip(
            avatar: const Icon(
              Icons.check_circle,
              size: 16,
              color: Color(0xFF795548),
            ),
            label: const Text('Friends'),
            backgroundColor: const Color(0xFF795548).withOpacity(0.1),
            shape: const StadiumBorder(),
          );
        }
        return TextButton.icon(
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
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Add'),
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
