import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userLanguage;
  late AppLocalizations localizations;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserLanguage().then((language) {
      setState(() {
        _userLanguage = language;
      });
    });
  }

  Future<String> _fetchUserLanguage() async {
    if (user == null) return 'en';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (userDoc.exists) {
      return userDoc['language'] ?? 'en';
    }
    return 'en';
  }

  Future<void> _updateLanguage(String newLanguage) async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .update({'language': newLanguage});

    setState(() {
      _userLanguage = newLanguage;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Initialize localizations based on user language
    localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!)) ?? AppLocalizations.of(context)!
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              _buildUserInfo(user!),
              const Divider(),
            ],
            Text(localizations.language,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildLanguageDropdown(),
            const Spacer(),
            Center(
              child: Text(
                localizations.welcomeMessage,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(User user) {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null ? const Icon(Icons.person, size: 30) : null,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.displayName ?? 'No name',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              user.email ?? 'No email',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown() {
    return Container(
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
    );
  }
}