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

  /// The uid whose role has actually been confirmed (via [getUserRole] or
  /// the live [_roleSub] listener) and is safe to route on. This is a
  /// belt-and-suspenders guard on top of the constructor's own ordering
  /// (which already only calls [notifyListeners] once role resolution is
  /// done): app.dart additionally refuses to route to Home/a dashboard
  /// unless THIS matches the currently signed-in uid, so no matter what
  /// interleaving of auth events/async gaps produces a mismatch between
  /// `currentUser` and `_cachedRole`, the wrong screen can never render —
  /// it shows a spinner instead until the role for that specific uid is
  /// confirmed. See [isRoleReadyForCurrentUser].
  String? _roleReadyForUid;

  /// True once [_roleReadyForUid] matches the currently signed-in user (or
  /// there's no signed-in user at all, in which case there's nothing to
  /// wait for). app.dart gates routing on this in addition to
  /// [authInitialized].
  bool get isRoleReadyForCurrentUser =>
      currentUser == null || _roleReadyForUid == currentUser!.uid;

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

  // Bumped on every authStateChanges event and used to discard the result
  // of a slower, now-superseded event's getUserRole() call if a newer
  // event's role has already resolved and notified first — see the
  // constructor below for why this matters.
  int _authEventGeneration = 0;

  // When true, the constructor's authStateChanges() listener below does
  // nothing at all — no role fetch, no _cachedRole/_roleReadyForUid
  // mutation, no notifyListeners(). Set by [loginAsVisitor] while it's
  // signing in and checking whether the account is actually staff, so
  // that this listener (which reacts to the SAME underlying Firebase Auth
  // state change independently and knows nothing about "this attempt
  // might get rejected") can never race ahead and broadcast a staff role
  // to the rest of the app — see [loginAsVisitor]'s doc comment for the
  // full explanation of the bug this closes.
  bool _suppressAuthBroadcast = false;

  AuthService() {
    // Listen to auth state changes so role is always fresh, and keep a live
    // subscription to that user's own doc so a role change made *while*
    // they're signed in (e.g. a Super Admin edit in the Firebase Console)
    // takes effect immediately instead of only on the next login.
    //
    // On some cold starts (a persisted staff/Super Admin session being
    // restored), authStateChanges() has been observed to emit a transient
    // `null` event before the real, already-signed-in user — while
    // `_auth.currentUser` (the live getter app.dart reads) has *already*
    // flipped back to that real user by the time this callback body runs.
    // If we trusted the event's own `user` payload for that first event,
    // we'd reset _cachedRole to 'visitor' and notify — and since
    // app.dart's routing reads auth.currentUser live (not this event's
    // payload), it would see the real signed-in Super Admin but a
    // 'visitor' role, and flash the visitor Home screen for the second or
    // so it takes the *next* (real) event's getUserRole() call to correct
    // it. Reading `_auth.currentUser` fresh here — instead of the
    // stream's own payload — sidesteps that blip.
    _auth.authStateChanges().listen((event) async {
      if (_suppressAuthBroadcast) {
        debugPrint('[AuthService] authStateChanges event suppressed '
            '(loginAsVisitor is mid-check): eventUser=${event?.uid} '
            'at ${DateTime.now()}');
        return;
      }
      final myGeneration = ++_authEventGeneration;
      _authInitialized = true;
      await _roleSub?.cancel();
      _roleSub = null;
      final user = _auth.currentUser;
      // TEMPORARY diagnostic logging — see the "app-launch flash" entry in
      // the project doc. Safe to remove once that's confirmed fixed;
      // debugPrint is a no-op in release builds by default in this app's
      // existing usage elsewhere, so this is harmless to leave in the
      // meantime.
      debugPrint('[AuthService] authStateChanges event: '
          'eventUser=${event?.uid} liveCurrentUser=${user?.uid} '
          'gen=$myGeneration at ${DateTime.now()}');
      if (user != null) {
        final role = await getUserRole();
        debugPrint('[AuthService] getUserRole() resolved for ${user.uid}: '
            '$role gen=$myGeneration at ${DateTime.now()}');
        // A newer auth event has already resolved and notified while we
        // were awaiting Firestore — don't let this now-stale result
        // clobber it.
        if (myGeneration != _authEventGeneration) {
          debugPrint('[AuthService] discarding stale gen=$myGeneration '
              '(current=$_authEventGeneration)');
          return;
        }
        _cachedRole = role;
        _roleReadyForUid = user.uid;
        notifyListeners();
        _watchOwnUserDoc(user.uid, myGeneration);
      } else {
        _cachedRole = 'visitor';
        _cachedBoothId = null;
        _roleReadyForUid = null;
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

  /// Called only when a visitor backs out of VisitorRegisterScreen without
  /// registering or skipping, in the one case where arriving there had just
  /// silently created a brand-new anonymous session via ensureVisitorSession()
  /// moments earlier (see VisitorRegisterScreen.showSkip) — nothing has been
  /// earned on it yet, so it's safe to sign out of entirely.
  ///
  /// Deliberately different from [logout]: this does NOT call
  /// ensureVisitorSession() again afterward, and does NOT set
  /// [lastKnownMode] — the whole point is for app.dart's root screen to see
  /// no signed-in user and no last mode, so it falls back to showing
  /// RoleChoiceScreen again instead of silently landing on Home as a guest
  /// (which is what happened before this fix: that root screen is reactive
  /// to auth state, so simply popping the navigator wasn't enough once the
  /// anonymous sign-in had already completed underneath).
  Future<void> discardFreshVisitorSession() async {
    await _roleSub?.cancel();
    _roleSub = null;
    await _auth.signOut();
    _cachedRole = 'visitor';
    _cachedBoothId = null;
    notifyListeners();
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
          case 'expired':
            return 'That invite code has expired — ask your organizer for a new one.';
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
  /// Deliberately fetches `role` AND `accountStatus` from one read (rather
  /// than calling [getUserRole]) and — like [loginAsVisitor] — suppresses
  /// the constructor's `authStateChanges()` listener for the whole
  /// sign-in-and-check window. A banned staff account signing in here has
  /// the exact same race [loginAsVisitor]'s doc comment describes: this
  /// screen can itself be the app's bootstrap/root screen, so without
  /// suppression a banned account's real dashboard could flash into view
  /// before this method notices the ban and signs back out.
  ///
  /// Also rejects a plain `visitor` account, mirroring [loginAsVisitor]'s
  /// rejection of `exhibitor`/`super_admin` accounts — this screen
  /// (Exhibitor/Organizer login) is staff-only, so a visitor's credentials
  /// entered here are signed back out with a message pointing them at the
  /// Visitor login instead, rather than being let through into whatever
  /// screen a plain visitor role would otherwise land on.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _suppressAuthBroadcast = true;
    await _roleSub?.cancel();
    _roleSub = null;
    try {
      isLoading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = _auth.currentUser!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      final status = doc.data()?['accountStatus'] as String? ?? 'active';
      if (status == 'banned') {
        // Reject before this account's role is ever assigned to
        // `_cachedRole` — nothing here ever broadcasts a banned account as
        // successfully signed in with a resolved role.
        await _auth.signOut();
        _cachedRole = 'visitor';
        _cachedBoothId = null;
        _roleReadyForUid = null;
        return 'This account has been suspended. Contact the event '
            'organizers if you think this is a mistake.';
      }
      final role = doc.data()?['role'] as String? ?? 'visitor';
      if (role != 'exhibitor' && role != 'super_admin') {
        // Plain visitor credentials on the staff-only login screen — reject
        // and sign back out instead of routing them into the app, same
        // suppression guarantee as the ban check above so nothing flashes.
        await _auth.signOut();
        _cachedRole = 'visitor';
        _cachedBoothId = null;
        _roleReadyForUid = null;
        return 'This is a visitor account. Please use the Visitor login '
            'instead.';
      }
      _cachedRole = role;
      _roleReadyForUid = uid;
      final myGeneration = ++_authEventGeneration;
      _watchOwnUserDoc(uid, myGeneration);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      _suppressAuthBroadcast = false;
      isLoading = false;
      notifyListeners();
    }
  }

  /// Sets up (or replaces) the live subscription to `users/{uid}`'s
  /// `role`/`boothId` fields for whichever account is now confirmed
  /// signed in — shared by the constructor's `authStateChanges()`
  /// listener, [login], and [loginAsVisitor] so all three keep this
  /// behavior identical. [generation] is checked on every emission so a
  /// subscription left over from a since-superseded auth event can never
  /// clobber a newer one's state.
  void _watchOwnUserDoc(String uid, int generation) {
    _roleSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (generation != _authEventGeneration) return;
      final newRole = snap.data()?['role'] as String? ?? 'visitor';
      final newBoothId = snap.data()?['boothId'] as String?;
      _roleReadyForUid = uid;
      if (newRole != _cachedRole || newBoothId != _cachedBoothId) {
        _cachedRole = newRole;
        _cachedBoothId = newBoothId;
        notifyListeners();
      }
    });
  }

  /// VisitorLoginScreen's entry point — like [login], but rejects an
  /// exhibitor or Super Admin account instead of signing it in and routing
  /// to that staff dashboard. The Exhibitor/Organizer LoginScreen has no
  /// equivalent restriction on visitor accounts (a deliberate, separate
  /// decision) — this one exists specifically so a visitor who mistakenly
  /// types their own exhibitor credentials into the wrong screen is told
  /// so, rather than silently dropped into the Exhibitor Dashboard.
  ///
  /// Deliberately does NOT call the shared [login] helper. [login] sets
  /// `_cachedRole` and calls `notifyListeners()` the moment it discovers
  /// the role — but the constructor's `authStateChanges()` listener reacts
  /// to the SAME underlying Firebase Auth sign-in independently and
  /// concurrently (signing in with email/password fires its own auth-state
  /// event, regardless of which code path initiated the sign-in), and that
  /// listener has no idea this particular attempt might get rejected a
  /// moment later. The result, confirmed by inspection: typing a Super
  /// Admin/exhibitor account's credentials into the Visitor Login screen
  /// (when it's the app's current bootstrap/root screen) could briefly
  /// but visibly swap the screen to that account's real dashboard — the
  /// same reactive-root mechanism as the app-launch-flash bug elsewhere in
  /// this project, just triggered by an interactive login instead of a
  /// cold start. This method sets [_suppressAuthBroadcast] for the whole
  /// sign-in-and-check window so the constructor's listener does nothing
  /// while it runs, keeps the freshly-looked-up role in a local variable
  /// (never touching `_cachedRole`) until the account is confirmed to be a
  /// plain visitor, and only then lifts suppression and broadcasts —
  /// guaranteeing `_cachedRole` can never become `'exhibitor'`/
  /// `'super_admin'` at any point a rejected attempt is in flight.
  Future<String?> loginAsVisitor({
    required String email,
    required String password,
  }) async {
    _suppressAuthBroadcast = true;
    // Cancel any live role subscription for whoever was signed in before
    // (e.g. an existing anonymous guest session) up front — normally the
    // constructor's listener does this the instant sign-in succeeds, but
    // it's suppressed for the whole duration of this method, so a stale
    // subscription would otherwise keep listening under the OLD uid while
    // briefly signed in as the staff account being checked below.
    await _roleSub?.cancel();
    _roleSub = null;
    try {
      isLoading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = _auth.currentUser!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      final status = doc.data()?['accountStatus'] as String? ?? 'active';
      final role = doc.data()?['role'] as String? ?? 'visitor';
      if (status == 'banned') {
        // A banned account is rejected here regardless of role — a banned
        // plain visitor (role == 'visitor') must not be able to log back
        // in through this screen either, same as a banned exhibitor/Super
        // Admin trying the Exhibitor Login screen (see [login]).
        await _auth.signOut();
        _cachedRole = 'visitor';
        _cachedBoothId = null;
        _roleReadyForUid = null;
        _suppressAuthBroadcast = false;
        notifyListeners();
        await ensureVisitorSession();
        return 'This account has been suspended. Contact the event '
            'organizers if you think this is a mistake.';
      }
      if (role == 'exhibitor' || role == 'super_admin') {
        // Reject: sign back out before this role is ever assigned to
        // `_cachedRole` — the rest of the app (including the reactive root
        // in app.dart) never sees this account as signed in with a
        // resolved staff role at any point.
        await _auth.signOut();
        _cachedRole = 'visitor';
        _cachedBoothId = null;
        _roleReadyForUid = null;
        _suppressAuthBroadcast = false;
        notifyListeners();
        // Restore a guest session so the visitor isn't left stranded with
        // no account at all (same "never a login wall" principle as
        // ensureVisitorSession elsewhere). Suppression is already lifted,
        // so the constructor's listener picks this new anonymous session
        // up normally, same as any other guest sign-in.
        await ensureVisitorSession();
        return 'This is an exhibitor account. Please use the Exhibitor '
            'login instead.';
      }
      // Confirmed a plain, non-banned visitor — safe to broadcast now.
      _cachedRole = role;
      _roleReadyForUid = uid;
      final myGeneration = ++_authEventGeneration;
      _suppressAuthBroadcast = false;
      notifyListeners();
      _watchOwnUserDoc(uid, myGeneration);
      return null;
    } on FirebaseAuthException catch (e) {
      _suppressAuthBroadcast = false;
      return e.message;
    } catch (e) {
      _suppressAuthBroadcast = false;
      return e.toString();
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

  // ── Forced logout on ban (visitor accounts, at the app root) ────────────
  /// Set by [forceLogoutForBan] right before it signs the account out, and
  /// read once by app.dart's `_BanNoticeGate` — the login/role-choice
  /// screen the visitor lands on right after this forced sign-out — to show
  /// a one-time blocking popup explaining why they were signed out. Cleared
  /// via [clearPendingBanMessage] once that popup has been shown, so it
  /// never reappears on a later, unrelated visit to that same screen.
  String? _pendingBanMessage;
  String? get pendingBanMessage => _pendingBanMessage;

  void clearPendingBanMessage() {
    if (_pendingBanMessage == null) return;
    _pendingBanMessage = null;
    notifyListeners();
  }

  // Guards [forceLogoutForBan] against overlapping calls: app.dart's
  // ban-check StreamBuilder schedules a call on every frame it rebuilds
  // while still showing a banned visitor as signed in, and `logout()`
  // below is async — several such frames can fire before `currentUser`
  // actually goes null and the ban check stops being reached at all.
  bool _banLogoutInFlight = false;

  /// Called by app.dart the moment its root ban-check sees
  /// `accountStatus == 'banned'` for a currently-signed-in VISITOR sitting
  /// at the app root (Home) with nothing pushed on top. Unlike the passive
  /// `_BannedScreen` still shown for a banned exhibitor/Super Admin (who
  /// must tap "Sign Out" themselves), a banned visitor here is signed out
  /// immediately and automatically — no button, no further chance to keep
  /// using the app from this screen — and [message] is stashed for the
  /// login/role-choice screen this lands them on to show once, via a
  /// blocking popup dialog, so they know why.
  Future<void> forceLogoutForBan(String message) async {
    if (_banLogoutInFlight) return;
    _banLogoutInFlight = true;
    _pendingBanMessage = message;
    try {
      await logout();
    } finally {
      _banLogoutInFlight = false;
    }
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
