import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes.dart';

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

  // Load the stored language preference
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String languageCode = prefs.getString('language') ?? 'en';

  runApp(MyApp(initialLanguageCode: languageCode));
}

class MyApp extends StatefulWidget {
  final String initialLanguageCode;

  const MyApp({Key? key, required this.initialLanguageCode}) : super(key: key);

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
    _locale = Locale(widget.initialLanguageCode);
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
    return MaterialApp(
      title: 'Kitchenly',
      debugShowCheckedModeBanner: false,
      locale: _locale, // Apply the saved language preference
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
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
