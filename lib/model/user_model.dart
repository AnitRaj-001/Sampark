import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String name;
  String email;
  String image;
  Timestamp date;
  String uid;

  UserModel(
      {required this.name,
      required this.email,
      required this.image,
      required this.date,
      required this.uid});

  factory UserModel.fromJson(DocumentSnapshot snapshot) {
    return UserModel(
      name: snapshot['name'],
      email: snapshot['email'],
      image: snapshot['image'],
      date: snapshot['date'],
      uid: snapshot['uid'],
    );
  }
}
