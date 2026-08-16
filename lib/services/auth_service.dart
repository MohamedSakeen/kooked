import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<AppUser?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final appUser = AppUser(
      uid: cred.user!.uid,
      name: name,
      email: email,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(cred.user!.uid)
        .set(appUser.toMap());

    return appUser;
  }

  Future<AppUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getCurrentAppUser();
  }

  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await _google.authenticate();

    final googleAuth = googleUser.authentication;
    final authz = await googleUser.authorizationClient.authorizationForScopes([]);
    final credential = GoogleAuthProvider.credential(
      accessToken: authz?.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    // Check if user doc exists, create if not
    final doc = await _firestore.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      final appUser = AppUser(
        uid: cred.user!.uid,
        name: cred.user!.displayName ?? '',
        email: cred.user!.email ?? '',
        photoUrl: cred.user!.photoURL,
        householdId: null,
        createdAt: DateTime.now(),
      );
      await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .set(appUser.toMap());
      return appUser;
    }

    return AppUser.fromFirestore(doc);
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _google.signOut(),
    ]);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
