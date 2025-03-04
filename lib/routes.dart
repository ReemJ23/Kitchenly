import 'package:flutter/material.dart';
import 'package:kitchenly/screens/signup_screen.dart';
import 'package:kitchenly/screens/login_screen.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import 'package:kitchenly/screens/welcome_screen.dart';

class AppRoutes {
  static const String signup = '/signup';
  static const String login = '/login';
  static const String profile = '/profile';
  static const String welcome = '/welcome';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case signup:
        final language = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => SignUpScreen(language: language));

      case login:
        final language = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => LoginScreen(language: language));

      case profile:
        final language = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => ProfileScreen(language: language));

      case welcome:
        return MaterialPageRoute(builder: (_) => WelcomeScreen());

      default:
        return MaterialPageRoute(builder: (_) => LoginScreen(language: 'en')); // Default to login
    }
  }
}
