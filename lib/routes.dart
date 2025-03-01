import 'package:flutter/material.dart';
import 'package:kitchenly/screens/signup_screen.dart';
import 'package:kitchenly/screens/login_screen.dart';
import 'package:kitchenly/screens/profile_screen.dart';

class AppRoutes {
  static const String signup = '/signup';
  static const String login = '/login';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case signup:
        return MaterialPageRoute(builder: (_) => SignUpScreen());

      case login:
        return MaterialPageRoute(builder: (_) => LoginScreen());

      case profile:
        final language = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => ProfileScreen(language: language));

      default:
        return MaterialPageRoute(builder: (_) => LoginScreen()); // Default to login
    }
  }
}
