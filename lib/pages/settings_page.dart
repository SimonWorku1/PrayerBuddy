import 'package:flutter/material.dart';
import 'account_actions_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B8B7A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B4EFF),
              ),
            ),
            const SizedBox(height: 20),

            // Account actions as a clickable tab
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFF6B4EFF)),
                title: const Text('Account'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountActionsPage()),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // App Info section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B8B7A),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: Color(0xFF6B4EFF),
                      ),
                      title: Text('Version'),
                      subtitle: Text('1.0.0'),
                    ),

                    const ListTile(
                      leading: Icon(
                        Icons.description_outlined,
                        color: Color(0xFF6B4EFF),
                      ),
                      title: Text('Terms of Service'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    ),

                    const ListTile(
                      leading: Icon(
                        Icons.privacy_tip_outlined,
                        color: Color(0xFF6B4EFF),
                      ),
                      title: Text('Privacy Policy'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
