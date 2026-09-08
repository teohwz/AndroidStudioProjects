import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'firestore_service.dart';

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

  /// Super Admin is a distinct, separate role from the existing organizer
  /// 'admin' (which only manages Quiz/Lucky Draw/Exhibitors) — it has the
  /// highest authorization priority app-wide (rewards, inventory,
  /// redemptions, users). Deliberately NOT reachable through register() or
  /// any public UI: the only way a user becomes 'super_admin' is another
  /// Super Admin promoting them (FirestoreService.setUserRole, itself
  /// gated by Firestore Security Rules to require the requester already be
  /// a Super Admin), or a one-time manual edit in the Firebase Console for
  /// the very first account. See firestore.rules for the server-side half
  /// of this — the client-side check here is a convenience, not security.
  bool get isSuperAdmin => _cachedRole == 'super_admin';

  /// An exhibitor owns exactly one booth (`exhibitors/{myBoothId}`),
  /// created ONLY via AuthService.registerExhibitor() redeeming a
  /// Super-Admin-issued invite code — never through open registration.
  /// Replaces the old shared 'admin' role, which managed every
  /// exhibitor/quiz/lucky-draw globally; that role is retired from routing.
  bool get isExhibitor => _cachedRole == 'exhibitor';

  String? _cachedBoothId;
  String? get myBoothId => _cachedBoothId;

  /// Re-reads the cached role from Firestore without a full sign-out/in.
  /// Kept as a manual escape hatch, but role is now kept live automatically
  /// via [_roleSub] below — this is no longer the only way to pick up a
  /// change (e.g. a Super Admin edit made directly in the Firebase Console
  /// while this account is already signed in used to require a full
  /// logout/login before the app noticed; it now updates within a second).
  Future<void> refreshRole() async {
    _cachedRole = await getUserRole();
    notifyListeners();
  }

  // Live subscription to `users/{uid}`'s `role` field for whichever account
  // is currently signed in — re-created on every auth state change so a
  // role edited directly in Firestore (Console or another admin) is picked
  // up immediately, without requiring the affected user to log out/in.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleSub;

  /// True for a visitor who entered via QR scan / silent session (no
  /// email+password account). False once an organizer/exhibitor is logged in.
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // Set when ensureVisitorSession()'s signInAnonymously() call fails (e.g.
  // no network on the device/emulator, or Anonymous sign-in disabled in the
  // Firebase Console). Without this, a failure left the app on an infinite
  // spinner forever with zero feedback — see app.dart's _AuthErrorScreen.
  bool authFailed = false;
  String? authError;

  // ── Role-choice bootstrap (Exhibitor / Visitor entry screen) ────────────
  static const String _lastModeKey = 'last_auth_mode';

  /// Set by [logout] when staff (an exhibitor or a Super Admin — both sign
  /// in through the same LoginScreen) or a registered (email-linked)
  /// visitor signs out — null (never set, or a guest with nothing to log
  /// out of) | 'exhibitor' (staff login page) | 'visitor'. app.dart's
  /// bootstrap screen reads this whenever there's no current Firebase
  /// session to decide whether to show the Role Choice screen (never
  /// set), the (Exhibitor/Super Admin) Login page, or the Visitor Login
  /// page — see [loadLastMode] and [logout].
  String? _lastKnownMode;
  String? get lastKnownMode => _lastKnownMode;

  /// True once the very first `authStateChanges` event has been received
  /// (whether it carried a signed-in user or not). app.dart shows a plain
  /// spinner until this flips, so a returning user's already-persisted
  /// session has a chance to resolve before any login/role-choice screen
  /// is ever shown — avoiding a one-frame flash of the wrong screen.
  bool _authInitialized = false;
  bool get authInitialized => _authInitialized;

  /// Reads the persisted "last login mode" flag from disk. Local-only
  /// (SharedPreferences) — no network or Firebase call — so it's cheap and
  /// safe to await at app start, before any session is established. See
  /// main.dart.
  Future<void> loadLastMode() async {
    final prefs = await SharedPreferences.getInstance();
    _lastKnownMode = prefs.getString(_lastModeKey);
  }

  Future<void> _saveLastMode(String? mode) async {
    _lastKnownMode = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_lastModeKey);
    } else {
      await prefs.setString(_lastModeKey, mode);
    }
  }

  AuthService() {
    // Listen to auth state changes so role is always fresh, and keep a live
    // subscription to that user's own doc so a role change made *while*
    // they're signed in (e.g. a Super Admin edit in the Firebase Console)
    // takes effect immediately instead of only on the next login.
    _auth.authStateChanges().listen((user) async {
      _authInitialized = true;
      await _roleSub?.cancel();
      _roleSub = null;
      if (user != null) {
        _cachedRole = await getUserRole();
        notifyListeners();
        _roleSub = _db
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snap) {
          final newRole = snap.data()?['role'] as String? ?? 'visitor';
          final newBoothId = snap.data()?['boothId'] as String?;
          if (newRole != _cachedRole || newBoothId != _cachedBoothId) {
            _cachedRole = newRole;
            _cachedBoothId = newBoothId;
            notifyListeners();
          }
        });
      } else {
        _cachedRole = 'visitor';
        _cachedBoothId = null;
        notifyListeners();
      }
    });
  }

  // ── Visitor session (no login/register required) ──────────────────────────
  /// Ensures there is *some* signed-in Firebase user so points, leaderboard
  /// entries, and booth check-ins have a stable uid to key off, without ever
  /// showing a visitor a login/register screen. Call once at app start.
  Future<void> ensureVisitorSession() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
      authFailed = false;
      authError = null;
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('Anonymous sign-in failed: ${e.code} ${e.message}. '
          'Make sure Anonymous sign-in is enabled in Firebase Console, '
          'and that the device/emulator has a working internet connection.');
      authFailed = true;
      authError = '${e.code}: ${e.message ?? 'Unknown error'}';
    } catch (e) {
      // Anything else (e.g. no network at all) — same fallback.
      // ignore: avoid_print
      print('Anonymous sign-in failed: $e');
      authFailed = true;
      authError = e.toString();
    }
    notifyListeners();
  }

  /// Called from the retry button shown when ensureVisitorSession() failed.
  Future<void> retryVisitorSession() async {
    authFailed = false;
    authError = null;
    notifyListeners();
    await ensureVisitorSession();
  }

  // ── Register (LEGACY — no longer reachable from any UI route) ───────────
  // This used to be the organizer/exhibitor open self-registration flow
  // (RegisterScreen, role defaulted to 'admin'). That role and this open
  // path are retired — see registerExhibitor() below for how an exhibitor
  // account is created now. Left in place, unused, rather than deleted.
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

  // ── Exhibitor registration (invite-code gated — the ONLY way an
  // exhibitor account is ever created) ────────────────────────────────────
  /// Creates a brand-new Firebase Auth account for an exhibitor and, in the
  /// same step, atomically consumes [code] to link it to that code's booth
  /// (see FirestoreService.redeemExhibitorInvite). If the redemption fails
  /// for any reason (bad/used code, race with another redeemer) the
  /// just-created auth account is deleted again rather than left as an
  /// orphan with no role or booth — this app has no backend to clean that
  /// up later. Returns null on success, or a user-facing error message.
  Future<String?> registerExhibitor({
    required String code,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user?.uid;
      if (uid == null) return 'Could not create the account — try again.';

      final outcome = await FirestoreService().redeemExhibitorInvite(
        code: code.trim().toUpperCase(),
        uid: uid,
        displayName: displayName,
        email: email,
      );

      if (!outcome.success) {
        try {
          await cred.user?.delete();
        } catch (_) {
          // Best-effort cleanup — if this fails there's a harmless orphan
          // auth account with no role/booth, which can't sign in anywhere
          // useful and can be removed manually from the Firebase Console.
        }
        switch (outcome.failureReason) {
          case 'already_used':
            return 'That invite code has already been used.';
          case 'booth_already_claimed':
            return 'That booth already has an owner.';
          case 'booth_missing':
            return 'That code\'s booth no longer exists — contact your organizer.';
          default:
            return 'Invalid invite code.';
        }
      }

      if (displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      _cachedRole = 'exhibitor';
      _cachedBoothId = outcome.redemptionId; // booth id, on success
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
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

  // ── Save points: upgrade the anonymous session in-place ────────────────
  /// Links an email+password credential onto the CURRENT anonymous user via
  /// `linkWithCredential`, which keeps the same uid (and therefore every
  /// point/badge/owned item already earned) instead of creating a brand-new
  /// account. This is the visitor-facing "save my points" flow — never a
  /// requirement to play, always an optional upgrade a visitor chooses.
  /// After success, `currentUser.isAnonymous` becomes false automatically.
  Future<String?> linkEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'No active session to save.';
    try {
      isLoading = true;
      notifyListeners();
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      final result = await user.linkWithCredential(credential);
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        await result.user?.updateDisplayName(name);
      }
      // Mirror the email (and name, if provided) so users/{uid} and
      // leaderboard/{uid} reflect the now-permanent account. merge: true —
      // this doc already exists for any visitor who has earned points, but
      // stays safe even for one who links before playing anything.
      await _db.collection('users').doc(user.uid).set(
        {
          'email': email,
          if (name != null && name.isNotEmpty) 'displayName': name,
        },
        SetOptions(merge: true),
      );
      if (name != null && name.isNotEmpty) {
        await _db.collection('leaderboard').doc(user.uid).set(
          {'displayName': name},
          SetOptions(merge: true),
        );
      }
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
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
  /// Signs the current account out. What happens next depends on who was
  /// signed in:
  /// - **Staff** (an exhibitor OR a Super Admin — both sign in through the
  ///   same `LoginScreen`): no anonymous session is silently
  ///   re-established — the "last mode" flag is set to `'exhibitor'` (the
  ///   flag just names which login page to show, not the role itself) so
  ///   app.dart's bootstrap screen shows that Login page on this and every
  ///   future launch, until they log back in. (Callers such as
  ///   ExhibitorDashboardScreen/SuperAdminDashboardScreen additionally
  ///   navigate there immediately, same as before.)
  /// - A **registered visitor** (linked email, `isAnonymous == false`,
  ///   role `'visitor'`): same idea, with `'visitor'` as the last mode —
  ///   the bootstrap screen shows the Visitor Login page instead.
  /// - Anything else (a guest with no credentials to sign out of):
  ///   unchanged prior behavior — silently re-establish a fresh anonymous
  ///   session so the app is never left with no signed-in user.
  Future<void> logout() async {
   /* await _googleSignIn.signOut();*/
    final wasStaff = isExhibitor || isSuperAdmin;
    final wasRegisteredVisitor = !isAnonymous && role == 'visitor';
    await _roleSub?.cancel();
    _roleSub = null;
    await _auth.signOut();
    _cachedRole = 'visitor';
    _cachedBoothId = null;
    notifyListeners();
    if (wasStaff) {
      await _saveLastMode('exhibitor');
      return;
    }
    if (wasRegisteredVisitor) {
      await _saveLastMode('visitor');
      return;
    }
    await ensureVisitorSession();
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
