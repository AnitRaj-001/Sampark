import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sampark/Screens/auth_screen.dart';
import 'package:sampark/Screens/search_screen.dart';
import 'package:sampark/model/user_model.dart';

// ignore: must_be_immutable
class HomePage extends StatefulWidget{
   UserModel user;
   HomePage(this.user, {super.key});
 

  @override
  State<StatefulWidget> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sampark',style: TextStyle(fontSize:20,fontWeight: FontWeight.bold),),
        centerTitle: true,
        backgroundColor: Colors.yellow,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen(widget.user)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}