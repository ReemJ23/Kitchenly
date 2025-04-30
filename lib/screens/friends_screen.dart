import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({Key? key}) : super(key: key);

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _sendFriendRequest(String username) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (query.docs.isEmpty || query.docs.first.id == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found or invalid")),
      );
      return;
    }

    final target = query.docs.first;
    final targetId = target.id;

    // Check if already friends
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final currentData = currentUserDoc.data() as Map<String, dynamic>;
    final List currentFriends = currentData['friends'] ?? [];

    if (currentFriends.contains(targetId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This user is already your friend.")),
      );
      return;
    }

    // Check if a pending friend request already exists in notifications
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .doc(targetId)
        .collection('notifications')
        .where('type', isEqualTo: 'friend_request')
        .where('fromUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend request already sent")),
      );
      return;
    }

    // Send the friend request as a notification
    // Fetch sender's username from Firestore
    final senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final senderData = senderDoc.data() as Map<String, dynamic>;
    final senderUsername = senderData['username'] ?? 'Someone';

    // Create notification
    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetId)
        .collection('notifications')
        .add({
      'title': 'Friend Request',
      'body': '$senderUsername sent you a friend request.',
      'type': 'friend_request',
      'fromUid': user.uid,
      'fromUsername': senderUsername,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'status': 'pending',
    });


    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Friend request sent")),
    );

    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Friends")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search username",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () =>
                      _sendFriendRequest(_searchController.text.trim()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final List friends = data['friends'] ?? [];

                  if (friends.isEmpty) {
                    return const Text("You have no friends yet.");
                  }

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(friends[index])
                            .get(),
                        builder: (context, friendSnapshot) {
                          if (!friendSnapshot.hasData) {
                            return const ListTile(title: Text("Unknown"));
                          }
                          final friendData = friendSnapshot.data!.data()
                              as Map<String, dynamic>;
                          return ListTile(
                            title: Text(friendData['username'] ?? 'Unknown'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              tooltip: "Remove Friend",
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Remove Friend"),
                                    content: Text(
                                        "Are you sure you want to remove ${friendData['username']}?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text("Remove"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true) return;

                                final friendUid = friends[index];

                                // Remove friend from current user
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'friends': FieldValue.arrayRemove([friendUid])
                                });

                                // Remove current user from friend's list
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(friendUid)
                                    .update({
                                  'friends': FieldValue.arrayRemove([user.uid])
                                });

                                // Notify the removed friend
                                final userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .get();

                                final userData = userDoc.data() as Map<String, dynamic>;
                                final currentUsername = userData['username'] ?? 'Someone';

                                // Notify the removed friend
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(friendUid)
                                    .collection('notifications')
                                    .add({
                                  'title': 'Friend Removed',
                                  'body':
                                      '$currentUsername removed you from their friends list.',
                                  'type': 'system',
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'read': false,
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Friend removed")),
                                );

                                setState(() {}); // Refresh UI
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
