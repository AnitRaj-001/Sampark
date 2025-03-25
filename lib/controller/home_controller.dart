import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:sampark/controller/auth_controller.dart';
import 'package:sampark/model/user_model.dart';

class HomeController extends GetxController {
  final Rx<UserModel?> currentUser = Get.find<AuthController>().currentUser;
  RxList<Map<String, dynamic>> conversations = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _fetchConversations();
  }

  void _fetchConversations() {
    currentUser.listen((user) {
      if (user != null) {
        FirebaseFirestore.instance
            .collection('user')
            .doc(user.uid)
            .collection('messages')
            .orderBy('date', descending: true)
            .snapshots()
            .listen((snapshot) {
          conversations.value = snapshot.docs.map((doc) => {
            'friendId': doc.id,
            ...doc.data(),
          }).toList();
        });
      }
    });
  }

  void navigateToChat(String friendId, String friendName, String friendImage) {
    Get.toNamed('/chat', arguments: {
      'friendId': friendId,
      'friendName': friendName,
      'friendImage': friendImage,
    });
  }

  void navigateToSearch() {
    Get.toNamed('/search');
  }
}