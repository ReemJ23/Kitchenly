import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  final String language;  // Accept language as a parameter

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

  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    String input = _userController.text.trim();
    String password = _passwordController.text.trim();

    try {
      UserCredential userCredential;

      if (input.contains('@')) {
        userCredential = await _auth.signInWithEmailAndPassword(email: input, password: password);
      } else {
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          setState(() {
            usernameOrEmailError = AppLocalizations.of(context)!.userNotFound;
          });
          return;
        }

        String email = userQuery.docs.first['email'];
        userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', widget.language);


      Navigator.pushNamedAndRemoveUntil(context, '/profile', (route) => false, arguments: widget.language);

    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          usernameOrEmailError = AppLocalizations.of(context)!.userNotFound;
        } else if (e.code == 'wrong-password') {
          passwordError = AppLocalizations.of(context)!.incorrectPassword;
        } else {
          usernameOrEmailError = 'An error occurred: ${e.message}';
        }
      });
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
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: localizations.password,
                        border: OutlineInputBorder(),
                        errorText: passwordError,
                      ),
                    ),
                    SizedBox(height: 20),

                    ElevatedButton(onPressed: _login, child: Text(localizations.login)),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/signup', arguments: widget.language);
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
