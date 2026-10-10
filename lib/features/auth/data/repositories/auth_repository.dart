import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Fetch or sync existing user profile from Cloud Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (doc.exists && data != null) {
      return UserModel.fromMap(data);
    }
    return null;
  }

  Stream<UserModel?> userProfileChanges(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return UserModel.fromMap(data);
    });
  }

  // Email & Password Registration
  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw Exception('Account was created, but the user session is unavailable.');
    }

    final newUser = UserModel(
      uid: firebaseUser.uid,
      name: name,
      email: email,
      photoUrl: '',
      role: 'customer',
    );

    await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
    return newUser;
  }

  // Email & Password Login
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Google Sign-In Integration
  Future<UserModel?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // Cancelled flow

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await _auth.signInWithCredential(credential);
    final User? firebaseUser = userCredential.user;

    if (firebaseUser == null) return null;

    // Check if user record already exists
    final doc =
        await _firestore.collection('users').doc(firebaseUser.uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      final newUser = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Customer',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        role: 'customer',
      );
      await _firestore
          .collection('users')
          .doc(newUser.uid)
          .set(newUser.toMap());
      return newUser;
    }
    return UserModel.fromMap(data);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
