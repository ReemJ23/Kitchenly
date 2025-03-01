import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String language,
  }) async {
    try {
      // Check if username already exists
      QuerySnapshot usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        return "username_taken";
      }

      // Create user in Firebase Authentication
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Add user to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email.trim(),
        'username': username.trim(),
        'language': language,
      });

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return "email_taken";
      }
      return e.message ?? "signUpFailed";
    }
  }

  Future<String?> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      UserCredential userCredential;

      if (usernameOrEmail.contains('@')) {
        // Login with email
        userCredential = await _auth.signInWithEmailAndPassword(
          email: usernameOrEmail.trim(),
          password: password.trim(),
        );
      } else {
        // Find email from username
        QuerySnapshot userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: usernameOrEmail.trim())
            .get();

        if (userQuery.docs.isEmpty) {
          return "user_not_found";
        }

        String email = userQuery.docs.first.get('email');

        // Login with retrieved email
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password.trim(),
        );
      }

      return null; // Null means success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        return "wrong_password";
      }
      if (e.code == 'user-not-found') {
        return "user_not_found";
      }
      return e.message ?? "loginFailed";
    }
  }
}
