import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/auth_page.dart';
import 'pages/profile_setup_page.dart';
import 'pages/settings_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
    const PrayerRequestsPage(),
    const AddPrayerPage(),
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
            _buildNavItem(1, Icons.chat_bubble_outline, Icons.chat_bubble, 'Prayers'),
            _buildNavItem(2, Icons.add_circle_outline, Icons.add_circle, 'Add'),
            _buildNavItem(3, Icons.notifications_outlined, Icons.notifications, 'Alerts'),
            _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
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
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF8B8B7A),
            ),
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
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8B8B7A)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B4EFF)),
              ),
            );
          }

          String userName = 'Friend';
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            if (userData != null && userData['name'] != null) {
              userName = userData['name'] as String;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $userName!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4EFF),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome to your Christian community feed',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF8B8B7A),
                  ),
                ),
                const SizedBox(height: 40),
                const Center(
                  child: Icon(
                    Icons.favorite,
                    size: 80,
                    color: Color(0xFF6B4EFF),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Your prayer community is here to support you',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8B8B7A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
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
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF8B8B7A),
          ),
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
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF8B8B7A),
          ),
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
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF8B8B7A),
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B8B7A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF8B8B7A)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Your Christian journey and prayer history',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF8B8B7A),
          ),
        ),
      ),
    );
  }
}
