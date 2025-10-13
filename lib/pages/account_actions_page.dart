import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';

class AccountActionsPage extends StatefulWidget {
  const AccountActionsPage({super.key});

  @override
  State<AccountActionsPage> createState() => _AccountActionsPageState();
}

class _AccountActionsPageState extends State<AccountActionsPage> {
  bool _busy = false;
  final _authService = AuthService();

  Future<bool> _reauthenticateWithSms() async {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber;
    if (user == null || phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on this account.')),
      );
      return false;
    }

    String verificationId = '';
    String code = '';
    final completer = Completer<bool>();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('SMS failed: ${e.message}')));
        if (!completer.isCompleted) completer.complete(false);
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
        if (code.isEmpty) {
          if (!completer.isCompleted) completer.complete(false);
          return;
        }
        try {
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: code,
          );
          await user.reauthenticateWithCredential(credential);
          if (!completer.isCompleted) completer.complete(true);
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
          if (!completer.isCompleted) completer.complete(false);
        }
      },
      codeAutoRetrievalTimeout: (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
      timeout: const Duration(seconds: 60),
    );

    // Wait for the result produced in callbacks
    return completer.future;
  }

  Future<bool> _reauthenticateWithEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email on this account.')),
      );
      return false;
    }
    setState(() => _busy = true);
    try {
      await user.sendEmailVerification();
      if (!mounted) return false;
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
        return true;
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
    return false;
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Choose verification method
    final method = await showModalBottomSheet<String>(
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
              onTap: () => Navigator.pop(context, 'email'),
            ),
          ],
        ),
      ),
    );
    if (method == null) return;

    bool ok = false;
    if (method == 'sms') ok = await _reauthenticateWithSms();
    if (method == 'email') ok = await _reauthenticateWithEmail();
    if (!ok) return;

    setState(() => _busy = true);
    try {
      // Release handle if present
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      final handle = data != null ? (data['handle'] ?? '') as String : '';
      if (handle.isNotEmpty) {
        final handleRef = FirebaseFirestore.instance
            .collection('handles')
            .doc(handle);
        await handleRef.delete();
      }
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

  Future<void> _linkEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController(text: user.email ?? '');
    final passwordController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add email to account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Set password (for email login)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;

    setState(() => _busy = true);
    try {
      final exists = await _authService.isEmailExists(
        email,
        excludeUserId: user.uid,
      );
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That email is already in use.')),
        );
        return;
      }

      final cred = EmailAuthProvider.credential(
        email: email,
        password: passwordController.text.trim().isEmpty
            ? 'TempPass#${DateTime.now().millisecondsSinceEpoch}'
            : passwordController.text.trim(),
      );

      await user.linkWithCredential(cred).then((value) => value).catchError((
        e,
      ) async {
        try {
          await user.updateEmail(email);
          // Return a dummy credential-like object by reloading and composing
          await user.reload();
          return await user.reauthenticateWithCredential(cred);
        } catch (_) {
          rethrow;
        }
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email added to your account.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add email: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String input = '';
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add phone number'),
        content: TextField(
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number e.g. +15551234567',
          ),
          onChanged: (v) => input = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty) return;

    setState(() => _busy = true);
    try {
      final exists = await _authService.isPhoneNumberExists(
        phone,
        excludeUserId: user.uid,
      );
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That phone number is already in use.')),
        );
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (cred) async {
          try {
            await user.linkWithCredential(cred);
          } catch (_) {}
        },
        verificationFailed: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (vId, _) async {
          final controller = TextEditingController();
          final code = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
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
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('Verify'),
                ),
              ],
            ),
          );
          if (code == null || code.isEmpty) return;
          final credential = PhoneAuthProvider.credential(
            verificationId: vId,
            smsCode: code,
          );
          try {
            await user.linkWithCredential(credential);
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'phone': phone}, SetOptions(merge: true));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phone number added to your account.'),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to link phone: $e')));
          }
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
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
                  leading: const Icon(Icons.logout, color: Color(0xFF795548)),
                  title: const Text('Sign out'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _busy
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Sign out?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseAuth.instance.signOut();
                            if (!mounted) return;
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/auth', (_) => false);
                          }
                        },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(
                    Icons.alternate_email,
                    color: Color(0xFF795548),
                  ),
                  title: const Text('Add email'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _busy ? null : _linkEmail,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.sms, color: Color(0xFF795548)),
                  title: const Text('Add phone number'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _busy ? null : _linkPhone,
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
