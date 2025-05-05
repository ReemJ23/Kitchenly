import 'package:flutter/material.dart';
import 'package:kitchenly/routes.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kitchenly/utils/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../main.dart';


class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin{
String selectedLanguage = 'en';
late AnimationController _rotationController;
int _currentIndex = 0;
double _opacity = 1.0;
late Timer _carouselTimer;

  List<String> dishImages = [
    "assets/images/dishes/pasta.png",
    "assets/images/dishes/steak.png",
    "assets/images/dishes/hummus.webp",
    "assets/images/dishes/pancake.webp",
    "assets/images/dishes/eggs_dish.png",
    "assets/images/dishes/salad.png"
  ];


  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();  // Load saved language on screen initialization
    _startImageAnimation();


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

void _startImageAnimation() {
  _carouselTimer = Timer.periodic(Duration(seconds: 3), (timer) {
    setState(() {
      _opacity = 0.0;
    });

    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _currentIndex = (_currentIndex + 1) % dishImages.length;
        _opacity = 1.0;
      });
    });
  });
}

  @override
  void dispose() {
   _carouselTimer.cancel();
    super.dispose();
    }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2, // Moves image higher
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 500),
                opacity: _opacity,
                child: Image.asset(
                  dishImages[_currentIndex],
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
            ),
            ),
          ),

          Positioned(
            bottom: 80,
            left: 30,
            right: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.welcomeMessage,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.heading1,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  localizations.welcomeSubMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.heading2,
                  fontSize: 16,
                ),
                ),
                SizedBox(height: 20),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio(
                          value: 'en',
                          groupValue: selectedLanguage,
                          onChanged: (value) => _changeLanguage(value as String),
                        ),
                        Text("English", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.heading2)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio(
                          value: 'ar',
                          groupValue: selectedLanguage,
                          onChanged: (value) => _changeLanguage(value as String),
                        ),
                        Text("العربية", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.heading2)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // 🔹 Sign Up Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.signup, arguments: selectedLanguage);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),

                  ),
                  child: Text(localizations.signUp),
                ),
                SizedBox(height: 10),

                // 🔹 Login Button
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.login, arguments: selectedLanguage);
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    foregroundColor: AppColors.buttonText,
                  ),
                  child: Text(localizations.login),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
