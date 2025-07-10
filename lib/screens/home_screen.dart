// Home Page
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  String? _currentUserId;
  List<Map<String, dynamic>> _chatList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    if (_currentUserId != null) {
      _loadChatList();
    }
  }

  Future<void> _loadChatList() async {
    try {
      QuerySnapshot chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .get();

      List<Map<String, dynamic>> chats = [];
      for (var doc in chatQuery.docs) {
        Map<String, dynamic> chatData = doc.data() as Map<String, dynamic>;

        String otherUserId = (chatData['participants'] as List)
            .firstWhere((id) => id != _currentUserId);

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          chats.add({
            'chatId': doc.id,
            'otherUserId': otherUserId,
            'name': userData['name'],
            'image': userData['image'],
            'lastMessage': chatData['lastMessage'] ?? '',
            'lastMessageTime': chatData['lastMessageTime'],
            'isOnline': userData['isOnline'] ?? false,
          });
        }
      }

      // Sort in memory by time
      chats.sort((a, b) {
        Timestamp? t1 = a['lastMessageTime'];
        Timestamp? t2 = b['lastMessageTime'];
        if (t1 == null && t2 == null) return 0;
        if (t1 == null) return 1;
        if (t2 == null) return -1;
        return t2.compareTo(t1);
      });

      setState(() {
        _chatList = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredChatList {
    if (_searchController.text.isEmpty) {
      return _chatList;
    }
    return _chatList.where((chat) {
      return chat['name']
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Chat List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChatList.isEmpty
                    ? const Center(
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 100, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No chats yet',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('Start a new conversation',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredChatList.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChatList[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(chat['image']),
                              child: chat['image'] ==
                                      'https://via.placeholder.com/150'
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(chat['name']),
                            subtitle: Text(
                              chat['lastMessage'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (chat['isOnline'])
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(chat['lastMessageTime']),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/chat',
                                arguments: {
                                  'chatId': chat['chatId'],
                                  'otherUserId': chat['otherUserId'],
                                  'name': chat['name'],
                                  'image': chat['image'],
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/new_user'),
        // ignore: sort_child_properties_last
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
