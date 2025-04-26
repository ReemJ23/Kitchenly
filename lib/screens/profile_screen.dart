import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../utils/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userLanguage;
  String? _imageBase64;
  late AppLocalizations localizations;
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _familyCodeController = TextEditingController();
  final TextEditingController _addFamilyUsernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditingUsername = false;
  bool _isChangingPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userLanguage = userDoc['language'] ?? 'en';
          _usernameController.text =
              userDoc['username'] ?? user?.displayName ?? '';
          _imageBase64 = userDoc['profilePicture'];
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLanguage(String newLanguage) async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'language': newLanguage});

      setState(() => _userLanguage = newLanguage);
    } catch (e) {
      print("Error updating language: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUsername() async {
    if (user == null || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'username': _usernameController.text});

      await user?.updateDisplayName(_usernameController.text);

      setState(() => _isEditingUsername = false);
    } catch (e) {
      print("Error updating username: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (user == null || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await user?.updatePassword(_passwordController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.passwordUpdated)),
      );
      setState(() => _isChangingPassword = false);
      _passwordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.passwordUpdateError)),
      );
      print("Error updating password: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);

      try {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({'profilePicture': base64Image});

        setState(() => _imageBase64 = base64Image);
      } catch (e) {
        print("Error uploading image: $e");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateFamilyCode() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Generate a random 6-digit code
      final code = (100000 + Random().nextInt(900000)).toString();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'familyCode': code});

      // 🎯 Instantly update the UI
      setState(() {
        _familyCodeController.text = code;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localizations.familyCodeGenerated}: $code')),
      );
    } catch (e) {
      print("Error generating family code: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _joinFamily() async {
    if (user == null || _familyCodeController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Implementation would depend on your family sharing logic
      // This is a placeholder for the actual implementation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.familyJoinSuccess)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.familyJoinError)),
      );
      print("Error joining family: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!)) ??
            AppLocalizations.of(context)!
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user != null) ...[
                      _buildUserInfoSection(),
                      const Divider(),
                    ],
                    _buildLanguageSection(),
                    const Divider(),
                    _buildPasswordSection(),
                    const Divider(),
                    _buildFriendsSection(),
                    const Divider(),
                    _buildFamilySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: _imageBase64 != null
                    ? MemoryImage(base64Decode(_imageBase64!))
                    : (user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null),
                child: _imageBase64 == null && user?.photoURL == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditingUsername)
                    Text(
                      user?.displayName ?? _usernameController.text,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  if (_isEditingUsername)
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: localizations.username,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.usernameRequired;
                        }
                        return null;
                      },
                    ),
                  Text(
                    user?.email ?? 'No email',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _isEditingUsername
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _isEditingUsername = false),
                      child: Text(localizations.cancel),
                    ),
                    ElevatedButton(
                      onPressed: _updateUsername,
                      child: Text(localizations.save),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: () => setState(() => _isEditingUsername = true),
                  child: Text(localizations.editProfile),
                ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.language,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _userLanguage ?? 'en',
            isExpanded: true,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: 'en',
                child: Text(localizations.english),
              ),
              DropdownMenuItem(
                value: 'ar',
                child: Text(localizations.arabic),
              ),
            ],
            onChanged: (String? newLanguage) {
              if (newLanguage != null) {
                _updateLanguage(newLanguage);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.changePassword,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (_isChangingPassword) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: localizations.newPassword,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localizations.passwordRequired;
              }
              if (value.length < 6) {
                return localizations.passwordTooShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isChangingPassword = false),
                child: Text(localizations.cancel),
              ),
              ElevatedButton(
                onPressed: _updatePassword,
                child: Text(localizations.save),
              ),
            ],
          ),
        ] else
          TextButton(
            onPressed: () => setState(() => _isChangingPassword = true),
            child: Text(localizations.changePassword),
          ),
      ],
    );
  }

  Widget _buildFriendsSection() {
    final friendController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.friends,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: friendController,
          decoration: InputDecoration(
            labelText: localizations.enterFriendUsername,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            final username = friendController.text.trim();
            if (username.isEmpty || user == null) return;

            final query = await FirebaseFirestore.instance
                .collection('users')
                .where('username', isEqualTo: username)
                .limit(1)
                .get();

            if (query.docs.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.friendNotFound)),
              );
              return;
            }

            final targetDoc = query.docs.first;
            final targetUid = targetDoc.id;

            if (targetUid == user!.uid) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.cannotAddYourself)),
              );
              return;
            }

            final friendReqRef = FirebaseFirestore.instance
                .collection('users')
                .doc(targetUid)
                .collection('friendRequests')
                .doc(user!.uid);

            final existing = await friendReqRef.get();
            if (existing.exists) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.friendRequestAlreadySent)),
              );
              return;
            }

            await friendReqRef.set({
              'username': user!.displayName ?? user!.email,
              'status': 'pending',
              'sentAt': FieldValue.serverTimestamp(),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.friendRequestSent)),
            );

            friendController.clear();
          },
          child: Text(localizations.addFriend),
        ),
      ],
    );
  }
  Widget _buildFriendRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.friendRequests,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('friendRequests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final requests = snapshot.data!.docs;

            if (requests.isEmpty) {
              return Text(localizations.noFriendRequests);
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                final requesterUid = req.id;
                final requesterName = req['username'];

                return ListTile(
                  title: Text(requesterName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          // Add each other as friends
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user!.uid)
                              .collection('friends')
                              .doc(requesterUid)
                              .set({
                            'username': requesterName,
                            'addedAt': FieldValue.serverTimestamp(),
                          });

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(requesterUid)
                              .collection('friends')
                              .doc(user!.uid)
                              .set({
                            'username': user!.displayName ?? user!.email,
                            'addedAt': FieldValue.serverTimestamp(),
                          });

                          // Update request status
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user!.uid)
                              .collection('friendRequests')
                              .doc(requesterUid)
                              .update({'status': 'accepted'});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user!.uid)
                              .collection('friendRequests')
                              .doc(requesterUid)
                              .update({'status': 'rejected'});
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFamilySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.familySharing,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(localizations.familySectionDescription,
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),

        // Show current family code
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            String familyCode = '';
            if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              if (data.containsKey('familyCode')) {
                familyCode = data['familyCode'] ?? '';
              }
            }

            if (familyCode.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.noFamilyCodeYet,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _generateFamilyCode,
                    child: Text(AppLocalizations.of(context)!.generateFamilyCode),
                  ),
                ],
              );
            }

            _familyCodeController.text = familyCode;

            return TextFormField(
              controller: _familyCodeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.familyCode,
                border: const OutlineInputBorder(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: _generateFamilyCode,
          child: Text(localizations.generateFamilyCode),
        ),

        const Divider(height: 32),
        _buildAddFamilyMemberSection(),
      ],
    );
  }

  Widget _buildAddFamilyMemberSection() {
    final permissions = {
      'shoppingList': false,
      'inventory': false,
      'recipes': false,
      'mealPlan': false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.addFamilyMember,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addFamilyUsernameController,
          decoration: InputDecoration(
            labelText: localizations.enterMemberUsername,
          ),
        ),
        const SizedBox(height: 12),
        Text(localizations.setPermissions),
        ...permissions.keys.map((key) => CheckboxListTile(
              title: Text(getPermissionLabel(localizations, key)),
              value: permissions[key],
              onChanged: (val) {
                permissions[key] = val!;
                setState(() {}); // Make sure UI updates
              },
            )),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final username = _addFamilyUsernameController.text.trim();

            if (username.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.usernameRequired)),
              );
              return;
            }

            final query = await FirebaseFirestore.instance
                .collection('users')
                .where('username', isEqualTo: username)
                .limit(1)
                .get();

            if (query.docs.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.userNotFound)),
              );
              return;
            }

            final memberUid = query.docs.first.id;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('familyMembers')
                .doc(memberUid)
                .set({
              'username': username,
              'permissions': permissions,
              'addedAt': FieldValue.serverTimestamp(),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.familyMemberAdded)),
            );

            _addFamilyUsernameController.clear();
          },
          child: Text(localizations.addMember),
        )
      ],
    );
  }

  String getPermissionLabel(AppLocalizations localizations, String key) {
    switch (key) {
      case 'shoppingList':
        return localizations.permissionShoppingList;
      case 'inventory':
        return localizations.permissionInventory;
      case 'recipes':
        return localizations.permissionRecipes;
      case 'mealPlan':
        return localizations.permissionMealPlan;
      default:
        return key;
    }
  }

  @override
  void dispose() {
    _addFamilyUsernameController.dispose();
    _passwordController.dispose();
    _familyCodeController.dispose();
    super.dispose();
  }
}
