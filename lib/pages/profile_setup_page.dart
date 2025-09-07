import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSetupPage extends StatefulWidget {
  final User user;

  const ProfileSetupPage({super.key, required this.user});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _handleController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill information based on how user signed up
    if (widget.user.email != null && widget.user.email!.isNotEmpty) {
      _emailController.text = widget.user.email!;
    }

    // Pre-fill phone if user signed up with phone
    if (widget.user.phoneNumber != null &&
        widget.user.phoneNumber!.isNotEmpty) {
      _phoneController.text = widget.user.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _handleController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _sanitizeHandle(String raw) => raw.trim().toLowerCase();

  Future<void> _claimHandleOnSignup() async {
    final db = FirebaseFirestore.instance;
    final user = widget.user;
    final newHandle = _sanitizeHandle(_handleController.text);

    if (newHandle.isEmpty ||
        !RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(newHandle)) {
      throw Exception('Handle must be 3-20 chars: a-z, 0-9, _');
    }

    final userRef = db.collection('users').doc(user.uid);
    final handleRef = db.collection('handles').doc(newHandle);

    await db.runTransaction((tx) async {
      final hSnap = await tx.get(handleRef);
      if (hSnap.exists) {
        // If another user owns it, block. If current user somehow already owns
        // it, skip writing to avoid violating rules (no updates allowed).
        final hData = hSnap.data() as Map<String, dynamic>;
        if (hData['uid'] != user.uid) {
          throw Exception('This @handle is already taken');
        }
        // Owned by this user already; do nothing to `handles`.
      } else {
        tx.set(handleRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      tx.set(userRef, {
        'handle': newHandle,
        'handleUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Reserve handle first
      await _claimHandleOnSignup();

      // Save user profile to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({
            'handle': _sanitizeHandle(_handleController.text),
            'name': _nameController.text.trim(),
            'isPlaceholder': false,
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'email': _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'authProvider': widget.user.providerData.isNotEmpty
                ? widget.user.providerData.first.providerId
                : 'email',
          });

      // Navigate to main app
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: const Color(0xFF795548),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Welcome message
              const Text(
                'Welcome to PrayerBuddy!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF795548),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                'Please complete your profile to get started.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Handle field (required)
              TextFormField(
                controller: _handleController,
                decoration: const InputDecoration(
                  labelText: 'Handle (@username) *',
                  hintText: 'e.g. @john_doe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  final v = (value ?? '').trim().toLowerCase();
                  if (v.isEmpty) {
                    return 'Please choose a unique @handle';
                  }
                  if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v)) {
                    return '3-20 chars: a-z, 0-9, _';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Name field (required)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Phone field (optional)
              TextFormField(
                controller: _phoneController,
                enabled:
                    widget.user.phoneNumber == null ||
                    widget.user.phoneNumber!.isEmpty,
                decoration: InputDecoration(
                  labelText:
                      widget.user.phoneNumber != null &&
                          widget.user.phoneNumber!.isNotEmpty
                      ? 'Phone Number (From Sign Up)'
                      : 'Phone Number (Optional)',
                  hintText: 'Enter your phone number',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                  filled:
                      widget.user.phoneNumber != null &&
                      widget.user.phoneNumber!.isNotEmpty,
                  fillColor:
                      widget.user.phoneNumber != null &&
                          widget.user.phoneNumber!.isNotEmpty
                      ? Colors.grey[200]
                      : null,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    // Basic phone validation
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Email field (optional, pre-filled if available)
              TextFormField(
                controller: _emailController,
                enabled:
                    widget.user.email == null || widget.user.email!.isEmpty,
                decoration: InputDecoration(
                  labelText:
                      widget.user.email != null && widget.user.email!.isNotEmpty
                      ? 'Email (From Sign Up)'
                      : 'Email (Optional)',
                  hintText: 'Enter your email address',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                  filled:
                      widget.user.email != null &&
                      widget.user.email!.isNotEmpty,
                  fillColor:
                      widget.user.email != null && widget.user.email!.isNotEmpty
                      ? Colors.grey[200]
                      : null,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    // Basic email validation
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$',
                    ).hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF795548),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Complete Setup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // Skip button (optional)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        // Save minimal profile and continue
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.user.uid)
                              .set({
                                'name': 'User',
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                                'authProvider':
                                    widget.user.providerData.isNotEmpty
                                    ? widget.user.providerData.first.providerId
                                    : 'email',
                              });

                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed('/home');
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Color(0xFF795548), fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
