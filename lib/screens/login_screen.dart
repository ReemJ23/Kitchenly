import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/colors.dart';
import 'family_login_screen.dart';

class LoginScreen extends StatefulWidget {
  final String language;

  const LoginScreen({Key? key, required this.language}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  String? usernameOrEmailError;
  String? passwordError;

  bool isUserEmpty = false;
  bool isPasswordEmpty = false;

  bool _obscurePassword = true;

  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() {
      usernameOrEmailError = null;
      passwordError = null;
      isUserEmpty = _userController.text.isEmpty;
      isPasswordEmpty = _passwordController.text.isEmpty;
    });

    if (_userController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    String input = _userController.text.trim();
    String password = _passwordController.text.trim();
    try {
      UserCredential userCredential;

      if (input.contains('@')) {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
      } else {
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          setState(() {
            usernameOrEmailError = localizations.userNotFound;
          });
          return;
        }

        String email = userQuery.docs.first['email'];

        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', widget.language);
      await prefs.remove('family_owner_uid');
      await prefs.remove('family_member_name');
      await prefs.remove('family_member_permission');

      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: widget.language);

    }  on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          usernameOrEmailError = localizations.userNotFound;
        } else if (e.code == 'invalid-credential') {
          passwordError = localizations.wrongPassword;
        } else {
          passwordError = localizations.loginErrorGeneric;
        }
      });
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
                localizations.loginMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.heading1,
                  fontSize: 24,
                  fontWeight: FontWeight.bold

                ),
              ),
              SizedBox(height: 5),
              Text(
                localizations.loginSubMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.heading2,
                  fontSize: 16,
                ),

              ),

              SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username or Email Field
                    TextFormField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: localizations.emailOrUsername,
                        border: OutlineInputBorder(),
                        errorText: usernameOrEmailError,
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

                    ElevatedButton(onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(350, 55),
                        ),
                        child: Text(localizations.login) ),
                    SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FamilyLoginScreen(language: widget.language)),
                        );
                      },
                      child: Text(localizations.loginAsFamily),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/signup', arguments: widget.language);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(350, 55)),
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
