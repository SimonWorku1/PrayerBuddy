import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '262497079999-gmkgko3fnss9pt572gt2aehdgp5sedvc.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  // Initialize testing mode for iOS Simulator
  static Future<void> initializeTestingMode() async {
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google Sign In - handles both new and existing users
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Sign out from Google first to force account selection
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign In was cancelled by the user.');
      }

      // Get the authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this user already has a profile in our database
      if (userCredential.user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // This is a new user, check for duplicate email in our database
          final emailExists = await isEmailExists(googleUser.email);
          if (emailExists) {
            // Sign out and throw error
            await _auth.signOut();
            throw Exception('An account with this email already exists.');
          }
        }
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Phone authentication - send verification code
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification if SMS code is detected automatically
          try {
            final userCredential = await _auth.signInWithCredential(credential);

            // Check if this user already has a profile in our database
            if (userCredential.user != null) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userCredential.user!.uid)
                  .get();

              if (!userDoc.exists) {
                // This is a new user, check for duplicate phone in our database
                final phoneExists = await isPhoneNumberExists(
                  userCredential.user!.phoneNumber ?? '',
                  excludeUserId: userCredential.user!.uid,
                );
                if (phoneExists) {
                  // Sign out and throw error
                  await _auth.signOut();
                  onVerificationFailed(
                    FirebaseAuthException(
                      code: 'phone-number-already-exists',
                      message:
                          'An account with this phone number already exists.',
                    ),
                  );
                  return;
                }
              }
            }

            onVerificationCompleted(credential.smsCode ?? '');
          } catch (e) {
            onVerificationFailed(
              FirebaseAuthException(
                code: 'auto-verification-failed',
                message: 'Auto-verification failed: ${e.toString()}',
              ),
            );
          }
        },
        verificationFailed: onVerificationFailed,
        codeSent: (String verificationId, int? resendToken) {
          // Store verification ID for later use
          _verificationId = verificationId;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Phone authentication - verify SMS code
  Future<UserCredential> verifyPhoneCode(String smsCode) async {
    try {
      if (_verificationId == null) {
        throw Exception('No verification ID found. Please request a new code.');
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this user already has a profile in our database
      if (userCredential.user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // This is a new user, check for duplicate phone/email
          final phoneExists = await isPhoneNumberExists(
            userCredential.user!.phoneNumber ?? '',
            excludeUserId: userCredential.user!.uid,
          );
          if (phoneExists) {
            // Sign out and throw error
            await _auth.signOut();
            throw Exception(
              'An account with this phone number already exists.',
            );
          }
        }
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      // If Google sign out fails, still try to sign out from Firebase
      await _auth.signOut();
    }
  }

  // Handle Firebase Auth errors
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'invalid-verification-code':
          return 'Invalid verification code. Please try again.';
        case 'invalid-verification-id':
          return 'Verification session expired. Please request a new code.';
        case 'quota-exceeded':
          return 'SMS quota exceeded. Please try again later.';
        case 'operation-not-allowed':
          return 'Phone authentication is not enabled for this app.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address but different sign-in credentials.';
        case 'invalid-credential':
          return 'The credential is invalid or has expired.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'phone-number-already-exists':
          return 'An account with this phone number already exists.';
        default:
          return 'Authentication failed: ${e.message}';
      }
    }
    return 'An error occurred: ${e.toString()}';
  }

  // Check if phone number already exists in database (excluding current user)
  Future<bool> isPhoneNumberExists(
    String phoneNumber, {
    String? excludeUserId,
  }) async {
    try {
      final cleanPhone = _getCleanPhoneNumber(phoneNumber);
      print('Checking for phone number: $cleanPhone');

      // Get all users and check for phone number matches
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final doc in querySnapshot.docs) {
        // Skip the current user if excludeUserId is provided
        if (excludeUserId != null && doc.id == excludeUserId) {
          print('Skipping current user: ${doc.id}');
          continue;
        }

        final userData = doc.data();
        if (userData['phone'] != null) {
          final existingPhone = _getCleanPhoneNumber(userData['phone']);
          print('Comparing with existing phone: $existingPhone');
          if (existingPhone == cleanPhone && existingPhone.isNotEmpty) {
            print('Phone number match found!');
            return true;
          }
        }
      }

      print('No duplicate phone number found');
      return false;
    } catch (e) {
      print('Error checking phone number: $e');
      return false;
    }
  }

  // Check if email already exists in database
  Future<bool> isEmailExists(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  // Helper method to clean phone number for comparison
  String _getCleanPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      return '';
    }

    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // If it starts with country code, keep it as is
    if (digitsOnly.startsWith('1') && digitsOnly.length == 11) {
      return '+$digitsOnly';
    }

    // If it's 10 digits, assume US number
    if (digitsOnly.length == 10) {
      return '+1$digitsOnly';
    }

    // If it's 11 digits and doesn't start with 1, assume it's a country code
    if (digitsOnly.length == 11) {
      return '+$digitsOnly';
    }

    // Return as is if it already has country code
    if (phoneNumber.startsWith('+')) {
      return phoneNumber;
    }

    // For any other format, just return the digits with +
    if (digitsOnly.isNotEmpty) {
      return '+$digitsOnly';
    }

    return phoneNumber;
  }

  // Store verification ID for phone auth
  String? _verificationId;
}
