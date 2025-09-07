import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/phone_formatter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _authService = AuthService();

  AuthMethod _selectedMethod = AuthMethod.none;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _phoneCodeSent = false;
  String _verificationId = '';
  String _selectedCountry = 'US';
  String _formattedPhoneNumber = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _selectMethod(AuthMethod method) {
    setState(() {
      _selectedMethod = method;
      _errorMessage = '';
      _phoneCodeSent = false;
      _formattedPhoneNumber = '';
    });
  }

  void _goBack() {
    setState(() {
      _selectedMethod = AuthMethod.none;
      _errorMessage = '';
      _phoneCodeSent = false;
      _formattedPhoneNumber = '';
    });
  }

  void _onPhoneNumberChanged(String value) {
    setState(() {
      _formattedPhoneNumber = PhoneFormatter.formatPhoneNumber(
        value,
        _selectedCountry,
      );
    });
  }

  void _onCountryChanged(String? newCountry) {
    if (newCountry != null) {
      setState(() {
        _selectedCountry = newCountry;
        if (_phoneController.text.isNotEmpty) {
          _formattedPhoneNumber = PhoneFormatter.formatPhoneNumber(
            _phoneController.text,
            _selectedCountry,
          );
        }
      });
    }
  }

  Future<void> _handlePhoneAuth() async {
    if (_phoneCodeSent) {
      // Verify SMS code
      if (_smsCodeController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter the verification code';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await _authService.verifyPhoneCode(_smsCodeController.text);
        // Phone verification successful - Firebase auth state will update automatically
        print('Phone auth successful');

        // Clear the form
        setState(() {
          _phoneCodeSent = false;
          _smsCodeController.clear();
          _phoneController.clear();
        });
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Send verification code
      if (_phoneController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your phone number';
        });
        return;
      }

      // Validate phone number
      if (!PhoneFormatter.isValidPhoneNumber(
        _phoneController.text,
        _selectedCountry,
      )) {
        setState(() {
          _errorMessage =
              'Please enter a valid phone number for $_selectedCountry';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Get clean phone number for Firebase
        String cleanPhoneNumber = PhoneFormatter.getCleanPhoneNumber(
          _phoneController.text,
          _selectedCountry,
        );

        await _authService.verifyPhoneNumber(
          phoneNumber: cleanPhoneNumber,
          onCodeSent: (String verificationId) {
            setState(() {
              _verificationId = verificationId;
              _phoneCodeSent = true;
              _isLoading = false;
            });
          },
          onVerificationCompleted: (String smsCode) {
            // Auto-verification completed
            setState(() {
              _phoneCodeSent = false;
              _isLoading = false;
            });
          },
          onVerificationFailed: (FirebaseAuthException e) {
            setState(() {
              _errorMessage = e.message ?? 'Verification failed';
              _isLoading = false;
            });
          },
          onCodeAutoRetrievalTimeout: (String verificationId) {
            setState(() {
              _errorMessage =
                  'SMS code retrieval timed out. Please enter manually.';
              _isLoading = false;
            });
          },
        );
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo/Title
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF795548),
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF795548).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Welcome Text
                Text(
                  'Welcome to PrayerBuddy',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B8B7A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you\'d like to sign in',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF8B8B7A).withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 40),

                // Show different content based on selected method
                if (_selectedMethod == AuthMethod.none) ...[
                  _buildMethodSelection(),
                ] else if (_selectedMethod == AuthMethod.phone) ...[
                  _buildPhoneAuth(),
                ] else if (_selectedMethod == AuthMethod.google) ...[
                  _buildGoogleAuth(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Phone Authentication Button
          _buildAuthMethodButton(
            icon: Icons.phone_android,
            title: 'Continue with Phone',
            subtitle: 'Sign in with your phone number',
            onTap: () => _selectMethod(AuthMethod.phone),
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 16),

          // Google Authentication Button
          _buildAuthMethodButton(
            icon: Icons.g_mobiledata,
            title: 'Continue with Google',
            subtitle: 'Sign in with your Google account',
            onTap: () => _selectMethod(AuthMethod.google),
            color: const Color(0xFFDB4437),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthMethodButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF8B8B7A).withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withOpacity(0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneAuth() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back, color: Color(0xFF8B8B7A)),
              ),
              Expanded(
                child: Text(
                  _phoneCodeSent
                      ? 'Enter Verification Code'
                      : 'Phone Authentication',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B8B7A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),
          const SizedBox(height: 24),

          if (!_phoneCodeSent) ...[
            // Country Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.flag),
                ),
                items: PhoneFormatter.countryCodes.keys.map((String country) {
                  return DropdownMenuItem<String>(
                    value: country,
                    child: Row(
                      children: [
                        Text(country),
                        const SizedBox(width: 8),
                        Text(
                          PhoneFormatter.countryCodes[country]!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onCountryChanged,
              ),
            ),
            const SizedBox(height: 20),

            // Phone Number Input
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_isLoading,
              onChanged: _onPhoneNumberChanged,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF4CAF50),
                    width: 2,
                  ),
                ),
                suffixIcon: _formattedPhoneNumber.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _formattedPhoneNumber,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!PhoneFormatter.isValidPhoneNumber(
                  value,
                  _selectedCountry,
                )) {
                  return 'Please enter a valid phone number for $_selectedCountry';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(
              'We\'ve sent a verification code to:',
              style: TextStyle(
                color: const Color(0xFF8B8B7A).withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formattedPhoneNumber.isNotEmpty
                  ? _formattedPhoneNumber
                  : _phoneController.text.trim(),
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _smsCodeController,
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Verification Code',
                hintText: '123456',
                prefixIcon: const Icon(Icons.security),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF4CAF50),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _phoneCodeSent = false;
                        _errorMessage = '';
                      });
                    },
              child: const Text(
                'Change Phone Number',
                style: TextStyle(color: Color(0xFF4CAF50)),
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),

          if (_errorMessage.isNotEmpty) const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePhoneAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _phoneCodeSent ? 'Verify Code' : 'Send Code',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleAuth() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back, color: Color(0xFF8B8B7A)),
              ),
              Expanded(
                child: Text(
                  'Google Sign In',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B8B7A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),
          const SizedBox(height: 24),

          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFDB4437).withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.g_mobiledata,
              size: 40,
              color: Color(0xFFDB4437),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Sign in with your Google account',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF8B8B7A).withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),

          if (_errorMessage.isNotEmpty) const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleGoogleAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDB4437),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.g_mobiledata, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

enum AuthMethod { none, phone, google }
