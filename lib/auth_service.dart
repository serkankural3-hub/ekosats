import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Emails that should have the `admin` role assigned.
  static const List<String> adminEmails = [
    'admin@ekos.com',
    'oytunsidal@ekos.com',
    'keremsidal@ekos.com',
    'sefaafyon@ekos.com',
    'ahmetkuscu@ekos.com',
    'mustafaakgul@ekos.com',
    'senaaydın@ekos.com',
  ];

  // Subset of admin emails that are allowed to edit/delete records.
  static const List<String> recordManagers = [
    'admin@ekos.com',
    'oytunsidal@ekos.com',
    'keremsidal@ekos.com',
    'sefaafyon@ekos.com',
    'ahmetkuscu@ekos.com',
  ];

  static bool isAdminEmail(String? email) {
    if (email == null) return false;
    return adminEmails.contains(email.toLowerCase());
  }

  static bool canManageRecordsByEmail(String? email) {
    if (email == null) return false;
    return recordManagers.contains(email.toLowerCase());
  }

    // Sign up with email & password
    // `signOut` exists for callers that expect to control whether the
    // application remains signed in after creating a user. (Caller may pass
    // `signOut: false` but desktop/mobile clients cannot create an account
    // without affecting the current auth state unless using server-side
    // admin APIs.)
    Future<Map<String, dynamic>?> signUp(String email, String password,
      {String role = 'user', bool signOut = true}) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': email.toLowerCase(),
        'role': role,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'email': email,
        'role': role,
        'status': 'approved',
        'uid': userCredential.user!.uid,
      };
    } catch (e) {
      print('signUp error: $e');
      return null;
    }
  }

  // Sign in with email & password
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'email': data['email'] ?? user.email,
        'role': data['role'] ?? 'user',
        'status': data['status'] ?? 'approved',
        'uid': user.uid,
      };
    }
    return {
      'email': user.email,
      'role': 'user',
      'status': 'approved',
      'uid': user.uid,
    };
  }

  Future<bool> isUserLoggedIn() async {
    return _auth.currentUser != null;
  }

  Future<void> updateUserRole(String uid, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'role': role});
  }

  Future<void> approveUser(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': 'approved'});
  }

  Future<void> deleteUser(String uid) async {
    // Firestore cleanup
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    // Note: Deleting from Auth requires Admin SDK on server side; not done here
  }

  Future<void> callFunction(String functionName, Map<String, dynamic> data) async {
    // Placeholder: call a cloud function via HTTPS or Callable if configured
    print('callFunction: $functionName with $data');
  }

  Future<void> clearCachedRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role_$uid');
  }

  // Kullanıcıyı pasife alma (status: 'disabled')
  Future<void> disableUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': 'disabled'});
    } catch (e) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'status': 'disabled'}, SetOptions(merge: true));
      } catch (e2) {
        rethrow;
      }
    }
  }

  // Get current user's role from Firestore (with local cache)
  Future<String?> getUserRole(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRole = prefs.getString('user_role_$uid');
      if (cachedRole != null) return cachedRole;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String? role;
      if (doc.exists) {
        role = (doc.data() as Map<String, dynamic>)['role'] as String?;
      } else {
        final user = FirebaseAuth.instance.currentUser;
        final email = user?.email?.toLowerCase();
        if (email != null) {
          if (email == 'pres@ekos.com') role = 'Pres sorumlusu';
          if (email == 'firin@ekos.com') role = 'Fırın Sorumlusu';
          if (email == 'laborant@ekos.com') role = 'Laborant';
          if (email == 'depo@ekos.com') role = 'Depo Sorumlusu';
          if (isAdminEmail(email)) role = 'admin';
        }
      }

      if (role != null) {
        await prefs.setString('user_role_$uid', role);
      }
      return role;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Ensure specific known emails have correct roles in Firestore.
  Future<void> ensureDefaultRoles() async {
    final Map<String, String> defaults = {
      'pres@ekos.com': 'Pres sorumlusu',
      'firin@ekos.com': 'Fırın Sorumlusu',
      'tugla@ekos.com': 'Tugla Sorumlusu',
      'lab@ekos.com': 'Laborant',
    };
    for (final e in adminEmails) {
      defaults[e] = 'admin';
    }

    for (final entry in defaults.entries) {
      try {
        final email = entry.key.toLowerCase();
        final role = entry.value;
        final query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
        if (query.docs.isNotEmpty) {
          for (final doc in query.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final currentRole = data['role'] as String?;
            if (currentRole != role) {
              await doc.reference.update({'role': role, 'status': 'approved'});
            }
          }
        }
      } catch (e) {
        print('ensureDefaultRoles error for ${entry.key}: $e');
      }
    }
  }

  // Assign role on sign-in if matches defaults
  Future<void> ensureRoleOnSignIn(User user) async {
    if (user.email == null) return;
    final email = user.email!.toLowerCase();
    final Map<String, String> defaults = {
      'pres@ekos.com': 'Pres sorumlusu',
      'firin@ekos.com': 'Fırın Sorumlusu',
      'tugla@ekos.com': 'Tugla Sorumlusu',
      'lab@ekos.com': 'Laborant',
    };
    for (final e in adminEmails) {
      defaults[e] = 'admin';
    }

    final role = defaults[email];
    if (role == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        if (data['role'] != role) {
          await docRef.update({'role': role, 'status': 'approved', 'email': email});
        }
      } else {
        await docRef.set({'email': email, 'role': role, 'status': 'approved', 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      print('ensureRoleOnSignIn error: $e');
    }
  }

  Future<void> clearCachedUserRole(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role_$uid');
    } catch (e) {
      print('Error clearing cached role: $e');
    }
  }
}
