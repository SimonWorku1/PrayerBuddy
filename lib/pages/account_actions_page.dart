import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountActionsPage extends StatefulWidget {
  const AccountActionsPage({super.key});

  @override
  State<AccountActionsPage> createState() => _AccountActionsPageState();
}

class _AccountActionsPageState extends State<AccountActionsPage> {
  bool _busy = false;

  Future<void> _signOutWithSms() async {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber;
    if (user == null || phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on this account.')),
      );
      return;
    }

    String verificationId = '';
    String code = '';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('SMS failed: ${e.message}')));
      },
      codeSent: (vId, _) async {
        verificationId = vId;
        await showDialog(
          context: context,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text('Enter SMS Code'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    code = controller.text.trim();
                    Navigator.pop(context);
                  },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );

        if (code.isEmpty) return;
        try {
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: code,
          );
          await user.reauthenticateWithCredential(credential);
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _signOutWithEmailLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email on this account.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check your email'),
          content: const Text(
            'We sent a verification link to your email. Click it, then return and continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I clicked the link'),
            ),
          ],
        ),
      );
      if (proceed == true) {
        await user.reload();
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Email flow failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF6B4EFF)),
                  title: const Text('Sign out'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _busy
                      ? null
                      : () async {
                          final choice = await showModalBottomSheet<String>(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.sms_outlined),
                                    title: const Text('Verify by SMS code'),
                                    onTap: () => Navigator.pop(context, 'sms'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.email_outlined),
                                    title: const Text('Verify by email link'),
                                    onTap: () =>
                                        Navigator.pop(context, 'email'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (choice == 'sms') {
                            await _signOutWithSms();
                          } else if (choice == 'email') {
                            await _signOutWithEmailLink();
                          }
                        },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _busy ? null : _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
