// lib/controller/search_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:sampark/model/user_model.dart';
import 'package:sampark/controller/auth_controller.dart';

class SearchController extends GetxController {
  final Rx<UserModel?> currentUser = Get.find<AuthController>().currentUser; // Use Rx directly
  RxString searchQuery = ''.obs;
  RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Optional: Log to debug
    ever(currentUser, (_) {
      print('Current user updated: ${currentUser.value?.uid}');
    });
  }

  void updateQuery(String value) {
    searchQuery.value = value;
    if (value.isEmpty) {
      searchResults.clear();
    }
  }

  Future<void> searchUsers() async {
    if (searchQuery.value.isEmpty || currentUser.value == null) return; // Guard against null user

    isLoading.value = true;
    searchResults.clear();

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchQuery.value)
          .where('name', isLessThanOrEqualTo: '${searchQuery.value}\uf8ff')
          .get();

      searchResults.value = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((user) => user['email'] != currentUser.value!.email) // Safe after null check
          .toList();
    } catch (e) {
      print('Search error: $e');
      Get.snackbar('Error', 'Failed to search: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void navigateToChat(String friendId, String friendName, String friendImage) {
    Get.toNamed('/chat', arguments: {
      'friendId': friendId,
      'friendName': friendName,
      'friendImage': friendImage,
    });
  }
}