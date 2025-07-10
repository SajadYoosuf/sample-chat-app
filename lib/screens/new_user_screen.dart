// New User Page
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewUserPage extends StatefulWidget {
  @override
  _NewUserPageState createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadUsers();
  }

  Future<void> _initializeAndLoadUsers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    await _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    try {
      QuerySnapshot userQuery =
          await FirebaseFirestore.instance.collection('users').get();

      List<Map<String, dynamic>> users = [];
      for (var doc in userQuery.docs) {
        if (doc.id != _currentUserId) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          users.add({
            'id': doc.id,
            'name': userData['name'],
            'phone': userData['phone'],
            'image': userData['image'],
            'isOnline': userData['isOnline'] ?? false,
          });
        }
      }

      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchController.text.isEmpty) {
      return _allUsers;
    }
    return _allUsers.where((user) {
      return user['name']
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
          user['phone'].contains(_searchController.text);
    }).toList();
  }

  Future<void> _startChat(String otherUserId, String name, String image) async {
    try {
      // Check if chat already exists
      QuerySnapshot existingChat = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .get();

      String? chatId;
      for (var doc in existingChat.docs) {
        final data = doc.data() as Map<String, dynamic>?;

        if (data == null) continue;

        final participants = (data['participants'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();

        if (participants == null) continue;

        if (participants.contains(otherUserId)) {
          chatId = doc.id;
          break;
        }
      }

      // If no existing chat, create new one
      if (chatId == null) {
        DocumentReference chatDoc =
            await FirebaseFirestore.instance.collection('chats').add({
          'participants': [_currentUserId, otherUserId],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        chatId = chatDoc.id;
      }

      // Navigate to chat page
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'chatId': chatId,
          'otherUserId': otherUserId,
          'name': name,
          'image': image,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error starting chat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 100, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No users found',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: NetworkImage(user['image']),
                                  child: user['image'] ==
                                          'https://via.placeholder.com/150'
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                if (user['isOnline'])
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(user['name']),
                            subtitle: Text(user['phone']),
                            trailing:
                                const Icon(Icons.chat, color: Colors.blue),
                            onTap: () => _startChat(
                                user['id'], user['name'], user['image']),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
