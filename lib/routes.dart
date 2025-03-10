import 'package:flutter/material.dart';
import 'package:kitchenly/screens/welcome_screen.dart';
import 'package:kitchenly/screens/signup_screen.dart';
import 'package:kitchenly/screens/login_screen.dart';
import 'package:kitchenly/screens/onboarding_allergies.dart';
import 'package:kitchenly/screens/onboarding_inventory.dart';
import 'package:kitchenly/screens/main_screen.dart';

class AppRoutes {
  static const String welcome = '/';
  static const String signup = '/signup';
  static const String login = '/login';
  static const String onboardingAllergies = '/onboarding_allergies';
  static const String onboardingInventory = '/onboarding_inventory';
  static const String main = '/main';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => WelcomeScreen());

      case signup:
        if (args is String) {
          return MaterialPageRoute(builder: (_) => SignUpScreen(language: args));
        }
        return _errorRoute();

      case login:
        if (args is String) {
          return MaterialPageRoute(builder: (_) => LoginScreen(language: args));
        }
        return _errorRoute();

      case onboardingAllergies:
        if (args is String) {
          return MaterialPageRoute(builder: (_) => OnboardingAllergiesScreen(language: args));
        }
        return _errorRoute();

      case onboardingInventory:
        if (args is String) {
          return MaterialPageRoute(builder: (_) => OnboardingInventoryScreen(language: args));
        }
        return _errorRoute();

      case main:
        if (args is String) {
          return MaterialPageRoute(builder: (_) => MainScreen(language: args));
        }
        return _errorRoute();

      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text("Error"),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Page not found"),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {

                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
                child: Text("Go to Home"),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
