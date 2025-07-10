// Profile Page
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');

    if (userId != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userInfo = userDoc.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfileImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'image': base64Image});

        setState(() {
          _userInfo!['image'] = base64Image;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_userInfo != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userInfo == null
              ? const Center(child: Text('Error loading profile'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _updateProfileImage,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundImage: _userInfo!['image'] != null &&
                                  _userInfo!['image']!.isNotEmpty
                              ? MemoryImage(base64Decode(_userInfo!['image']))
                              : null,
                          child: _userInfo!['image'] == null ||
                                  _userInfo!['image']!.isEmpty
                              ? const Icon(Icons.add_a_photo, size: 80)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Name'),
                          subtitle: Text(_userInfo!['name']),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.phone),
                          title: const Text('Phone Number'),
                          subtitle: Text(_userInfo!['phone']),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Joined'),
                          subtitle: Text(_formatDate(_userInfo!['createdAt'])),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _logout,
                          child: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
