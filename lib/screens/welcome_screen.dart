import 'package:flutter/material.dart';
import 'package:kitchenly/routes.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String selectedLanguage = 'en';  // Default language

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();  // Load saved language on screen initialization
  }

  // Load the stored language preference from SharedPreferences
  Future<void> _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedLanguage = prefs.getString('language');
    if (storedLanguage != null) {
      setState(() {
        selectedLanguage = storedLanguage;  // Update selected language
      });
    }
  }

  void _changeLanguage(String languageCode) {
    setState(() {
      selectedLanguage = languageCode;  // Update the selected language
    });
    MyApp.setLocale(context, languageCode);

    // Save the selected language to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('language', languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.welcomeMessage),
        automaticallyImplyLeading: false,  // Disable the back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              localizations.welcomeMessage,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // Language Selector with Radio buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio(
                  value: 'en',
                  groupValue: selectedLanguage,
                  onChanged: (value) => _changeLanguage(value as String),
                ),
                Text("English"),
                Radio(
                  value: 'ar',
                  groupValue: selectedLanguage,
                  onChanged: (value) => _changeLanguage(value as String),
                ),
                Text("العربية"),
              ],
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.signup, arguments: selectedLanguage);
              },
              child: Text(localizations.signUp),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.login, arguments: selectedLanguage);
              },
              child: Text(localizations.login),
            ),
          ],
        ),
      ),
    );
  }
}
