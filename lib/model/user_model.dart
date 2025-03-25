import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String image;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.image,
  });

  factory UserModel.fromJson(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'],
      name: data['name'],
      email: data['email'],
      image: data['image'],
    );
  }
}