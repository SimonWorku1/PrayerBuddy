import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/auth_page.dart';
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
          // User is signed in, show main app
          return const PrayerBuddyHomePage();
        }
        
        // User is not signed in, show auth page
        return const AuthPage();
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
      body: const Center(
        child: Text(
          'Welcome to your Christian community feed',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF8B8B7A),
          ),
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
            onPressed: () {},
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
