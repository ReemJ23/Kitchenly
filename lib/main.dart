import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes.dart';
import 'package:kitchenly/screens/welcome_screen.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import 'package:kitchenly/utils/font_helper.dart';
import 'package:kitchenly/utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: "AIzaSyD1jIdAupxLfvAlbYObaBZpK73cM7stbq8",
        authDomain: "kitchenly-64259.firebaseapp.com",
        projectId: "kitchenly-64259",
        storageBucket: "kitchenly-64259.firebasestorage.app",
        messagingSenderId: "282277301073",
        appId: "1:282277301073:web:7500d13cd519364869a170"));
  } else {
    await Firebase.initializeApp();
  }

  User? user = FirebaseAuth.instance.currentUser;
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? selectedLanguage = prefs.getString('language') ?? 'en';
  AppColors.initialize();
  runApp(MyApp(isLoggedIn: user != null, language: selectedLanguage));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final String language;

  const MyApp({Key? key, required this.isLoggedIn, required this.language}) : super(key: key);

  static void setLocale(BuildContext context, String languageCode) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.changeLanguage(languageCode);
  }

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.language);
  }

  void changeLanguage(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);

    setState(() {
      _locale = Locale(languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
        valueListenable: AppColors.themeVersion,
        builder: (context, _, __) {
          return MaterialApp(
            title: 'Kitchenly',
            debugShowCheckedModeBanner: false,
            locale: _locale,
            // Apply the saved language preference
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],
            theme: ThemeData(
              textTheme: TextTheme(
                bodyLarge: TextStyle(
                    fontFamily: FontHelper.getDefaultFontFamily(_locale),
                    fontSize: 18),
                bodyMedium: TextStyle(
                    fontFamily: FontHelper.getDefaultFontFamily(_locale),
                    fontSize: 16),
                bodySmall: TextStyle(
                    fontFamily: FontHelper.getDefaultFontFamily(_locale),
                    fontSize: 14),
                titleLarge: TextStyle(
                    fontFamily: FontHelper.getDefaultFontFamily(_locale),
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: TextStyle(color: AppColors.defaultLabel),
                // Default label color
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: AppColors.bottomBorder), // Bottom border
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.focusedBorder,
                      width: 2), // Blue border when focused
                ),
                errorBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: AppColors
                          .error), // Red border when there's an error
                ),
                focusedErrorBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.error,
                      width: 2), // Thicker red border on focus
                ),
                hintStyle: TextStyle(color: AppColors.hint),
              ),

              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.toggleActive,
                primary: AppColors.toggleActive,
              ),


              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(350, 55),
                    backgroundColor: AppColors.buttonBg,
                    textStyle: TextStyle(
                      fontFamily: FontHelper.getDefaultFontFamily(_locale),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    foregroundColor: AppColors.buttonText,
                    overlayColor: AppColors.buttonBgOnPressed
                ),
              ),

              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    minimumSize: Size(350, 55),
                    textStyle: TextStyle(
                      fontFamily: FontHelper.getDefaultFontFamily(_locale),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    foregroundColor: AppColors.buttonText,
                    overlayColor: AppColors.buttonBgOnPressed
                ),
              ),

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                    minimumSize: Size(350, 55),
                    textStyle: TextStyle(
                      fontFamily: FontHelper.getDefaultFontFamily(_locale),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    foregroundColor: AppColors.buttonText,
                    overlayColor: AppColors.buttonBgOnPressed
                ),
              ),
            ),
            home: InitialScreen(
                isLoggedIn: widget.isLoggedIn, language: widget.language),
            onGenerateRoute: AppRoutes.generateRoute,
          );
        }
    );
  }
}
class InitialScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String language;

  const InitialScreen({Key? key, required this.isLoggedIn, required this.language}) : super(key: key);

  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      Navigator.pushReplacementNamed(context, widget.isLoggedIn ? '/main' : '/welcome', arguments: widget.language);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator())); // Show loading while redirecting
  }
}