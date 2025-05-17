import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchenly/screens/myrecipes_screen.dart';
import 'package:kitchenly/screens/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kitchenly/utils/colors.dart';
import 'dart:convert';
import 'dart:io';
import 'family_sync_screen.dart';
import 'friends_screen.dart';
import 'main_screen.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _isEditingUsername = false;
  bool _isChangingPassword = false;
  bool _isLoading = false;
  bool _hasNotifications = false;
  bool _obscurePassword = true;
  String? _selectedThemeName;
  int _selectedColorValue = 0x99BF8E73;
  final List<Map<String, dynamic>> _colorOptions = [
    {'value': 0xFF9CAF88, 'name': 'green'},
    {'value': 0xDD607D8B, 'name': 'blue'},
    {'value': 0xFFDCA06D, 'name': 'orange'},
    {'value': 0xDD8174A0, 'name': 'purple'},
    {'value': 0xFFBF7E73, 'name': 'red'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _fetchUserData();
    _checkExpiredIngredients();
    _checkForNotifications();
  }
  Future<void> _loadUserTheme() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final themeName = doc.data()?['theme'] as String?;
      if (themeName != null) {
        final colorData = _colorOptions.firstWhere(
              (color) => color['name'] == themeName,
          orElse: () => _colorOptions[0],
        );

        setState(() {
          _selectedThemeName = themeName;
          _selectedColorValue = colorData['value'];
        });
      }
    }
  }
  Future<void> _checkForNotifications() async {
    final hasNotifications = await _hasUnreadNotifications();
    setState(() {
      _hasNotifications = hasNotifications;
    });
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
          // _usernameController.text =
          //     userDoc['username'] ?? user?.displayName ?? '';
          _usernameController.text = userDoc['username'] ?? '';

          _imageBase64 = userDoc['profilePicture'];
          _selectedColorValue = userDoc.data()!.containsKey('themeColor')
              ? userDoc['themeColor']
              : 0xFF51271D;
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
    if (mounted)
      setState(() {
        _isEditingUsername = false;
      });
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

  Future<bool> _hasUnreadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<void> _checkExpiredIngredients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    // Only run once per day — optional (can be removed if not needed)
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString('last_expiration_check');
    final lastCheck =
        lastCheckStr != null ? DateTime.tryParse(lastCheckStr) : null;

    if (lastCheck != null &&
        lastCheck.year == now.year &&
        lastCheck.month == now.month &&
        lastCheck.day == now.day) {
      return; // Already checked today
    }

    final ingredientsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inventory')
        .get();

    for (final doc in ingredientsSnapshot.docs) {
      final data = doc.data();
      if (data['expirationDate'] != null && (data['notified'] != true)) {
        final expirationDate = (data['expirationDate'] as Timestamp).toDate();

        if (!expirationDate.isAfter(now)) {
          // 1. Send Notification
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .add({
            'title': 'Ingredient Expired',
            'body': 'The ingredient "${data['name']}" has expired!',
            'type': 'expiration',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

          // 2. Mark ingredient as notified
          await doc.reference.update({'notified': true});
        }
      }
    }

    // Save last check date
    await prefs.setString('last_expiration_check', now.toIso8601String());
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  Future<void> _changeThemeColor(int colorValue, String colorName) async {
    if (user == null) return;

    setState(() {
      _selectedColorValue = colorValue;
      _selectedThemeName = colorName;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'theme': colorName});
      }

      // Update app colors
      setState(() {
        AppColors.setTheme(colorName);
      });


      // Refresh the UI
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => MainScreen(language: _userLanguage!,),
            transitionDuration: Duration.zero,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update theme: ${e.toString()}')),
      );
    }
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
        centerTitle: true,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('notifications')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasUnread =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationsPage()),
                      );
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
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
                    _buildConnectionsSection(),
                    const Divider(),
                    _buildThemeSection(),
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
                    ? Image.asset(
                        'assets/images/icons/profile_chef_icon.png',
                        width: 60,
                        height: 60,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditingUsername)
                    // Text(
                    //   _usernameController.text.isEmpty
                    //       ? localizations.addUsername
                    //       : _usernameController.text,
                    //   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    // )
                    // ,
                    GestureDetector(
                      onTap: () => setState(() => _isEditingUsername = true),
                      child: Text(
                        _usernameController.text.isEmpty
                            ? localizations.addUsername
                            : _usernameController.text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.heading1,
                          //fontStyle: _usernameController.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
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
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.heading2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Align(
          alignment: Alignment.center,
          child: _isEditingUsername
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: ElevatedButton(
                        onPressed: () =>
                            setState(() => _isEditingUsername = false),
                        child: Text(localizations.cancel),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.1,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: ElevatedButton(
                        onPressed: _updateUsername,
                        child: Text(localizations.save),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
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
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: localizations.newPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
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
              Container(
                width: MediaQuery.of(context).size.width * 0.4,
                child: ElevatedButton(
                  onPressed: () => setState(() => _isChangingPassword = false),
                  child: Text(localizations.cancel),
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.1),
              Container(
                width: MediaQuery.of(context).size.width * 0.4,
                child: ElevatedButton(
                  onPressed: _updatePassword,
                  child: Text(localizations.save),
                ),
              ),
            ],
          ),
        ] else
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isChangingPassword = true),
              child: Text(localizations.changePassword),
            ),
          ),
      ],
    );
  }
  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.theme,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: MediaQuery.of(context).size.height * 0.03),
        Center(
          child: Wrap(
            spacing: MediaQuery.of(context).size.width * 0.055,
            children: _colorOptions.map((colorData) {
              final isSelected = _selectedThemeName == colorData['name'];
              return GestureDetector(
                onTap: () => _changeThemeColor(
                  colorData['value'],
                  colorData['name'],
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(colorData['value']),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                      color: Colors.white,
                      width: 2,
                    )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  Widget _buildConnectionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.connections,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: Text(localizations.manageFriends),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FriendsPage()),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(localizations.manageFamily),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SyncCodePage()),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
