import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StartupScreen extends StatefulWidget {
  @override
  _StartupScreenState createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (!isFirstTime) {
      // Navigate to SignUp or Profile Page directly
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  Future<void> _saveLanguagePreference(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    await prefs.setBool('isFirstTime', false); // Mark as not first time
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chooseLanguage),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await _saveLanguagePreference('en'); // Save English preference
                Navigator.pushReplacementNamed(context, '/signup');
              },
              child: Text(AppLocalizations.of(context)!.english),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _saveLanguagePreference('ar'); // Save Arabic preference
                Navigator.pushReplacementNamed(context, '/signup');
              },
              child: Text(AppLocalizations.of(context)!.arabic),
            ),
          ],
        ),
      ),
    );
  }
}