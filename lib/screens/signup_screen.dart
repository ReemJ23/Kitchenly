import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../main.dart';
import '../utils/colors.dart';

class SignUpScreen extends StatefulWidget {
  final String language;  // Accept language as a parameter

  const SignUpScreen({Key? key, required this.language}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  String? emailError;
  String? passwordError;
  String? usernameError;

  bool isEmailEmpty = false;
  bool isPasswordEmpty = false;
  bool isUsernameEmpty = false;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    MyApp.setLocale(context, widget.language); // Set the language when the screen is initialized
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
      language: widget.language,
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
      await prefs.setString('language', widget.language);  // Store the language
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding_allergies', (route) => false, arguments:  widget.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
       appBar: AppBar(title: Text(" ")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizations.signupMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.heading1,
                  fontSize: 24,
                  fontWeight: FontWeight.bold

                ),
              ),
              SizedBox(height: 5), // Small spacing between texts
              Text(
                localizations.signupSubMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.heading2,
                  fontSize: 16,
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: localizations.email,
                        errorText: emailError,
                      ),
                    ),
                    SizedBox(height: 10),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: localizations.username,
                        errorText: usernameError,
                      ),
                    ),
                    SizedBox(height: 10),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: localizations.password,
                        errorText: passwordError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      ),

                    SizedBox(height: 20),

                    ElevatedButton(onPressed: _signUp,

                        child: Text(localizations.signUp)),
                    SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login', arguments: widget.language);
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
