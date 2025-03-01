import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../main.dart';
import '../utils/colors.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  String selectedLanguage = 'en';

  String? emailError;
  String? passwordError;
  String? usernameError;

  bool isEmailEmpty = false;
  bool isPasswordEmpty = false;
  bool isUsernameEmpty = false;

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

  Future<void> _signUp() async {
    setState(() {
      emailError = null;
      passwordError = null;
      usernameError = null;
      isEmailEmpty = _emailController.text.isEmpty;
      isPasswordEmpty = _passwordController.text.isEmpty;
      isUsernameEmpty = _usernameController.text.isEmpty;
    });

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      return;
    }

    String? result = await AuthService().signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      username: _usernameController.text.trim(),
      language: selectedLanguage,
    );

    if (result == "email_taken") {
      setState(() {
        emailError = AppLocalizations.of(context)!.emailTaken;
      });
    } else if (result == "username_taken") {
      setState(() {
        usernameError = AppLocalizations.of(context)!.usernameTaken;
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
      appBar: AppBar(title: Text(localizations.signUp)),
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
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: localizations.email,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isEmailEmpty ? AppColors.textFieldBorderError : AppColors.textFieldBorder,
                          ),
                        ),
                        errorText: emailError ?? (isEmailEmpty ? localizations.enterEmail : null),
                      ),
                    ),
                    SizedBox(height: 10),
        
                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: localizations.username,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isUsernameEmpty ? AppColors.textFieldBorderError : AppColors.textFieldBorder,
                          ),
                        ),
                        errorText: usernameError ?? (isUsernameEmpty ? localizations.enterUsername : null),
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
        
                    ElevatedButton(onPressed: _signUp, child: Text(localizations.signUp)),
        
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text(localizations.alreadyHaveAccount),
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
