import 'package:flutter/material.dart';
import 'package:kitchenly/routes.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kitchenly/utils/base_screen.dart';
import 'package:kitchenly/utils/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kitchenly/utils/font_helper.dart';

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

    return BaseScreen(
      hasIllustrations: true,


      // body: Padding(
      //   padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              localizations.welcomeMessage,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.heading1,
            ),
            textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // Language Selector with Radio buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio(
                      value: 'en',
                      groupValue: selectedLanguage,
                      onChanged: (value) => _changeLanguage(value as String),
                      activeColor: AppColors.radioButtonActive,
                    ),
                    Text("English", style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio(
                      value: 'ar',
                      groupValue: selectedLanguage,
                      onChanged: (value) => _changeLanguage(value as String),
                      activeColor: AppColors.radioButtonActive,
                    ),
                    Text("العربية", style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ],
            ),


            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.signup, arguments: selectedLanguage);
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                    if (states.contains(MaterialState.pressed)) {
                      return AppColors.buttonBgOnPressed;
                    }
                    return AppColors.buttonBg;
                  },
                ),
                foregroundColor: MaterialStateProperty.all(AppColors.buttonText),
                textStyle: MaterialStateProperty.all(
                  Theme.of(context).textTheme.bodySmall,
                ),
              ),
              child: Text(localizations.signUp),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.login, arguments: selectedLanguage);
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                    if (states.contains(MaterialState.pressed)) {
                      return AppColors.buttonBgOnPressed;
                    }
                    return Colors.transparent;
                  },
                ),
                foregroundColor: MaterialStateProperty.all(AppColors.buttonText),
                textStyle: MaterialStateProperty.all(
                  Theme.of(context).textTheme.bodySmall,
                ),
                padding: MaterialStateProperty.all(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              ),
              child: Text(localizations.login),
            ),
          ],
        // ),
      ),
    );
  }
}
