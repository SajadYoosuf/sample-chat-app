// Login Page
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  bool _isNewUser = false;
  bool _isLoading = false;

  Future<void> _login() async {
    if (_phoneController.text.trim().isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user exists in Firestore
      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: _phoneController.text.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        // New user
        setState(() {
          _isNewUser = true;
          _isLoading = false;
        });
      } else {
        // Existing user
        await _saveUserToPrefs(userQuery.docs.first.id);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Login failed. Please try again.');
    }
  }

  Future<void> _registerUser() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create new user in Firestore
      DocumentReference userDoc =
          await FirebaseFirestore.instance.collection('users').add({
        'phone': _phoneController.text.trim(),
        'name': _nameController.text.trim(),
        'image': _imageController.text.trim().isEmpty
            ? 'https://via.placeholder.com/150'
            : _imageController.text.trim(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _saveUserToPrefs(userDoc.id);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Registration failed. Please try again.');
    }
  }

  Future<void> _saveUserToPrefs(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', _phoneController.text.trim());
    await prefs.setString('user_id', userId);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat, size: 100, color: Colors.blue),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              enabled: !_isNewUser,
            ),
            const SizedBox(height: 16),
            if (_isNewUser) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'Profile Image URL (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isNewUser = false;
                    _nameController.clear();
                    _imageController.clear();
                  });
                },
                child: const Text('Back to Login'),
              ),
            ] else ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
