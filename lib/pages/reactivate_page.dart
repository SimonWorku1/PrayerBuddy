import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ReactivatePage extends StatelessWidget {
  const ReactivatePage({super.key});

  Future<bool> _isDeactivated(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.exists && (doc.data()?['isDeactivated'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FutureBuilder<bool>(
      future: _isDeactivated(user),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final isDeactivated = snap.data == true;
        if (!isDeactivated) {
          // If not deactivated, go home.
          Future.microtask(
            () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (_) => false),
          );
          return const SizedBox.shrink();
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5DC),
          appBar: AppBar(
            title: const Text('Reactivate'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Would you like to reactivate your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'If you reactivate, your posts, chats, and profile will become visible again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/auth', (_) => false);
                          }
                        },
                        child: const Text('No, sign out'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final svc = AuthService();
                          await svc.handleAccountReactivation(user.uid);
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/home', (_) => false);
                          }
                        },
                        child: const Text('Yes, reactivate'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
