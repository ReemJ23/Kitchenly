import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  String selectedLanguage = 'en';

  String? usernameOrEmailError;
  String? passwordError;

  bool isUserEmpty = false;
  bool isPasswordEmpty = false;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage = prefs.getString('language') ?? 'en';
    });
  }

  void _changeLanguage(String languageCode) {
    setState(() {
      selectedLanguage = languageCode;
    });

    MyApp.setLocale(context, languageCode);
  }

  Future<void> _login() async {
    setState(() {
      usernameOrEmailError = null;
      passwordError = null;
      isUserEmpty = _userController.text.isEmpty;
      isPasswordEmpty = _passwordController.text.isEmpty;
    });

    if (_userController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    String? result = await AuthService().login(
      usernameOrEmail: _userController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (result == "user_not_found") {
      setState(() {
        usernameOrEmailError = AppLocalizations.of(context)!.userNotFound;
      });
    } else if (result == "wrong_password") {
      setState(() {
        passwordError = AppLocalizations.of(context)!.incorrectPassword;
      });
    } else if (result == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', selectedLanguage);
      Navigator.pushReplacementNamed(context, '/profile', arguments: selectedLanguage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.login)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 🔹 Language Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio(
                    value: 'en',
                    groupValue: selectedLanguage,
                    onChanged: (value) => _changeLanguage(value as String),
                  ),
                  Text("English"),
                  Radio(
                    value: 'ar',
                    groupValue: selectedLanguage,
                    onChanged: (value) => _changeLanguage(value as String),
                  ),
                  Text("العربية"),
                ],
              ),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username or Email Field
                    TextFormField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: localizations.emailOrUsername,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isUserEmpty ? AppColors.textFieldBorderError : AppColors.textFieldBorder,
                          ),
                        ),
                        errorText: usernameOrEmailError ?? (isUserEmpty ? localizations.enterUsernameOrEmail : null),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: localizations.password,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isPasswordEmpty ? AppColors.textFieldBorderError : AppColors.textFieldBorder,
                          ),
                        ),
                        errorText: passwordError ?? (isPasswordEmpty ? localizations.enterPassword : null),
                      ),
                    ),
                    SizedBox(height: 20),

                    ElevatedButton(onPressed: _login, child: Text(localizations.login)),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/signup');
                      },
                      child: Text(localizations.dontHaveAccount),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
