import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/colors.dart';


class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.notifications)),
      body: user == null
          ? Center(child: Text(localizations.notSignedIn))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none, size: 72, color: AppColors.iconColor),
                        SizedBox(height: 12),
                        Text(localizations.noNotifications,
                            style: TextStyle(color: AppColors.heading2, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'];
                    final status = data['status'];
                    final isUnread = data['read'] != true;

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.dismissNotification,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: AppColors.iconColor),
                      ),
                      onDismissed: (_) async {
                        await doc.reference.delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(localizations.notificationDeleted)),
                        );
                      },
                      child: Container(
                        color: isUnread ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                        child: ListTile(
                          leading: const Icon(Icons.notifications),
                          title: Text(
                            _formatTimestamp(data['timestamp']),
                            style:
                                const TextStyle(fontSize: 12, color: AppColors.heading2),
                          ),
                          onTap: () async {
                            if (data['read'] != true) {
                              await doc.reference.update({'read': true});
                            }
                          },
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? localizations.notification),
                              Text(data['body'] ?? ''),
                              if (type == 'friend_request' &&
                                  status == 'pending') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.37,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.check,
                                            color: AppColors.acceptFriend),
                                        label: Text(localizations.accept),
                                        onPressed: () async {
                                          final fromUid = data['fromUid'];

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .update({
                                            'friends':
                                                FieldValue.arrayUnion([fromUid])
                                          });

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(fromUid)
                                              .update({
                                            'friends':
                                                FieldValue.arrayUnion([user.uid])
                                          });

                                          await doc.reference.update({
                                            'status': 'accepted',
                                            'read': true,
                                            'title': localizations.friendRequestAccepted,
                                            'body':
                                                '${localizations.youAcceptedRequest} ${data['fromUsername']}',
                                          });
                                          // Notify the sender that their request was accepted
                                          final currentUserDoc = await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .get();

                                          final currentData = currentUserDoc.data() as Map<String, dynamic>;
                                          final currentUsername = currentData['username'] ?? 'Someone';

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(fromUid)
                                              .collection('notifications')
                                              .add({
                                            'title': localizations.friendRequestAccepted,
                                            'body': '$currentUsername accepted your friend request.',
                                            'type': 'system',
                                            'timestamp': FieldValue.serverTimestamp(),
                                            'read': false,
                                          });
                                        },
                                      ),
                                    ),
                                    Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.37,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.clear,
                                            color: AppColors.declineFriend),
                                        label: Text(localizations.decline),
                                        onPressed: () async {
                                          await doc.reference.update({
                                            'status': 'rejected',
                                            'read': true,
                                            'title': localizations.friendRequestDeclined,
                                            'body':
                                                '${localizations.youDeclinedRequest} ${data['fromUsername']}',
                                          });

                                          // Notify the sender that their request was declined
                                          final currentUserDoc = await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .get();

                                          final currentData = currentUserDoc.data() as Map<String, dynamic>;
                                          final currentUsername = currentData['username'] ?? 'Someone';

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(data['fromUid'])
                                              .collection('notifications')
                                              .add({
                                            'title': localizations.friendRequestDeclined,
                                            'body': '$currentUsername declined your friend request.',
                                            'type': 'system',
                                            'timestamp': FieldValue.serverTimestamp(),
                                            'read': false,
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return '';
  }
}
