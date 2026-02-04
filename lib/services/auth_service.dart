import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }


  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await _saveUserToFirestore(user);
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _saveUserToFirestore(user);
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final userRef = _db.collection('users').doc(user.uid);
        if (!(await userRef.get()).exists) {
          await userRef.set({
            'uid': user.uid,
            'displayName': user.displayName,
            'email': user.email,
            'photoURL': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      } catch (e) {
        attempts++;
        debugPrint('Error saving user to Firestore (Attempt $attempts/$maxAttempts): $e');
        if (attempts < maxAttempts) {
          await Future.delayed(Duration(seconds: attempts));
        }
      }
    }
    debugPrint('Failed to save user to Firestore after $maxAttempts attempts.');
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    File? photoFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? photoURL = user.photoURL;

    try {
      if (photoFile != null) {
        final ref = _storage.ref().child('user_profiles/$uid.jpg');
        await ref.putFile(photoFile);
        photoURL = await ref.getDownloadURL();
      }

      if (name != null || photoURL != user.photoURL) {
        if (name != null) await user.updateDisplayName(name);
        if (photoURL != null) await user.updatePhotoURL(photoURL);

        await _db.collection('users').doc(uid).update({
          if (name != null) 'displayName': name,
          if (photoURL != null) 'photoURL': photoURL,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Ignore errors if Google Sign In is not available
    }
    await _auth.signOut();
  }
}
