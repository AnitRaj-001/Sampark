// lib/controller/auth_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sampark/model/user_model.dart';

class AuthController extends GetxController {
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    // Check initial auth state immediately
    final initialUser = _auth.currentUser;
    if (initialUser != null) {
      _fetchUserData(initialUser);
    }
    // Listen for changes
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _fetchUserData(user);
      } else {
        currentUser.value = null;
        print('AuthController: User logged out');
      }
    });
  }

  Future<void> _fetchUserData(User user) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      currentUser.value = UserModel.fromJson(userDoc);
      print('AuthController: User set to ${currentUser.value?.uid}');
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName,
          'image': userCredential.user!.photoURL,
          'uid': userCredential.user!.uid,
          'date': DateTime.now(),
        });
      }
      Get.offAllNamed('/home');
    } catch (e) {
      print('Sign-in error: $e');
      Get.snackbar('Error', 'Failed to sign in: $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    Get.offAllNamed('/auth');
  }
}