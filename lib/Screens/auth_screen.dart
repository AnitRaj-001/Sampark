import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sampark/main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

   @override
  State<StatefulWidget> createState() {
    return _AuthScreenState();
  }
}

class _AuthScreenState extends State<AuthScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future signinFunction() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if(googleUser==null){
      return;
    }
    final googleAuth = await googleUser.authentication;
    final credetials = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credetials);

    DocumentSnapshot userDoc = await firestore.collection('users').doc(userCredential.user!.uid).get();
    if(userDoc.exists){
      if (kDebugMode) {
        print("User does not exist");
      }
    }  else {
      await firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': userCredential.user!.email,
      'name': userCredential.user!.displayName,
      'image': userCredential.user!.photoURL,
      'uid': userCredential.user!.uid,
      'date':DateTime.now()
    });
    }
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(context)=>MyApp()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: 
          [
            SizedBox(height: 200),
            Image.asset('assets/images/logoApp.png', width: 200, height: 200),
            
            Text("Sampark", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            SizedBox(height: 250),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                width: double.infinity,
                height: 50,
                child: GestureDetector(
                  onTap: ()async{
                    await signinFunction();

                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: 
                    [
                      Image.asset('assets/images/Google.png', width: 25, height: 25),
                      SizedBox(width: 10),
                      Text("Login With Gmail", style: TextStyle(color: Colors.white, fontSize: 20)),
                    ],
                  ),
                )
              ),
            ),
          ], 
        ),
      ),
    );
  }
}