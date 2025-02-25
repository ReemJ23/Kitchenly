import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kitchenly/screens/Signup_screen.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import 'package:kitchenly/screens/startup_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  if(kIsWeb){
    await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: "AIzaSyD1jIdAupxLfvAlbYObaBZpK73cM7stbq8",
        authDomain: "kitchenly-64259.firebaseapp.com",
        projectId: "kitchenly-64259",
        storageBucket: "kitchenly-64259.firebasestorage.app",
        messagingSenderId: "282277301073",
        appId: "1:282277301073:web:7500d13cd519364869a170"));
  }else{
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitchenly',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        AppLocalizations.delegate, // Generated localization delegate
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'), // English
        Locale('ar'), // Arabic
      ],
      //home: StartupScreen(),
      initialRoute: '/',
      routes: {
        '/': (context) => StartupScreen(),
        '/signup': (context) => SignUpScreen(),
        '/profile': (context) => ProfileScreen(),
      },
    );
  }
}



