import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  /*final GoogleSignIn _googleSignIn = GoogleSignIn();*/

  User? get currentUser => _auth.currentUser;
  bool isLoading = false;

  // Cached role — loaded after login / register / app start
  String _cachedRole = 'visitor';
  String get role => _cachedRole;
  bool get isAdmin => _cachedRole == 'admin';

  AuthService() {
    // Listen to auth state changes so role is always fresh
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        _cachedRole = await getUserRole();
      } else {
        _cachedRole = 'visitor';
      }
      notifyListeners();
    });
  }

  // ── Register ────────────────────────────────────────────────────────────
  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
    String role = 'visitor',
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      final user = UserModel(
        uid: cred.user!.uid,
        displayName: displayName,
        email: email,
        role: role,
        points: 0,
        createdAt: DateTime.now(),
      );

      await _db
          .collection('users')
          .doc(cred.user!.uid)
          .set(user.toMap());

      // Also initialize leaderboard entry
      await _db
          .collection('leaderboard')
          .doc(cred.user!.uid)
          .set({
        'displayName': displayName,
        'totalPoints': 0,
        'gamesPlayed': 0,
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Login ───────────────────────────────────────────────────────────────
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      isLoading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _cachedRole = await getUserRole();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /*// ── Google Sign-In ────────────────────────────────────────────────────────
  Future<String?> signInWithGoogle() async {
    try {
      isLoading = true;
      notifyListeners();
 
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
 
      if (googleUser == null) {
        isLoading = false;
        notifyListeners();
        return 'Sign-in cancelled.';
      }
 
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
 
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
 
      final UserCredential userCred =
          await _auth.signInWithCredential(credential);
 
      final user = userCred.user!;
      final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;
 
      if (isNewUser) {
        await _createUserDocuments(
          uid: user.uid,
          displayName: user.displayName ?? googleUser.displayName ?? 'User',
          email: user.email ?? googleUser.email,
          role: 'visitor',
        );
      }
 
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
 */

  // ── Logout ──────────────────────────────────────────────────────────────
  Future<void> logout() async {
   /* await _googleSignIn.signOut();*/
    await _auth.signOut();
    _cachedRole = 'visitor';
    notifyListeners();
  }

  // ── Get user role ────────────────────────────────────────────────────────
  Future<String> getUserRole() async {
    if (currentUser == null) return 'visitor';
    final doc = await _db.collection('users').doc(currentUser!.uid).get();
    return doc.data()?['role'] ?? 'visitor';
  }

  // ── Shared helper ─────────────────────────────────────────────────────────
  Future<void> _createUserDocuments({
    required String uid,
    required String displayName,
    required String email,
    required String role,
  }) async {
    final user = UserModel(
      uid: uid,
      displayName: displayName,
      email: email,
      role: role,
      points: 0,
      createdAt: DateTime.now(),
    );
 
    await _db
        .collection('users')
        .doc(uid)
        .set(user.toMap(), SetOptions(merge: true));
 
    await _db.collection('leaderboard').doc(uid).set({
      'displayName': displayName,
      'totalPoints': 0,
      'gamesPlayed': 0,
    }, SetOptions(merge: true));
  }
}
