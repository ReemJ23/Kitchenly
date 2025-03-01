import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StartupScreen extends StatefulWidget {
  @override
  _StartupScreenState createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
    String? savedLanguage = prefs.getString('language') ?? 'en';

    if (!isFirstTime) {
      Navigator.pushReplacementNamed(context, '/signup', arguments: savedLanguage);
    }
  }

  Future<void> _saveLanguagePreference(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    await prefs.setBool('isFirstTime', false);

    // Restart the app with the new language
    Navigator.pushReplacementNamed(context, '/signup', arguments: languageCode);
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
              onPressed: () => _saveLanguagePreference('en'),
              child: Text(AppLocalizations.of(context)!.english),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _saveLanguagePreference('ar'),
              child: Text(AppLocalizations.of(context)!.arabic),
            ),
          ],
        ),
      ),
    );
  }
}
