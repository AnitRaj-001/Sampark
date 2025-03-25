import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sampark/controller/auth_controller.dart';
import 'package:sampark/controller/home_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    final animationController = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 500),
    )..forward();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sampark', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.yellow,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: Get.find<AuthController>().signOut,
          ),
        ],
      ),
      body: Obx(
        () => controller.conversations.isEmpty
            ? const Center(
                child: Text(
                  'No conversations yet.\nStart a chat!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: controller.conversations.length,
                itemBuilder: (context, index) {
                  final conversation = controller.conversations[index];
                  final friendId = conversation['friendId'];
                  final lastMessage = conversation['last_msg'] ?? 'No messages';
                  final timestamp = (conversation['date'] as Timestamp?)?.toDate();

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) return const SizedBox.shrink();

                      final friendData = userSnapshot.data!.data() as Map<String, dynamic>;
                      final friendName = friendData['name'] ?? 'Unknown';
                      final friendImage = friendData['image'] ?? '';

                      return AnimatedBuilder(
                        animation: animationController,
                        builder: (context, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animationController,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: FadeTransition(
                              opacity: animationController,
                              child: child,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: () => controller.navigateToChat(friendId, friendName, friendImage),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: NetworkImage(friendImage),
                                  radius: 25,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friendName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  timestamp != null ? DateFormat('h:mm a').format(timestamp) : '',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.navigateToSearch,
        backgroundColor: Colors.yellow,
        child: const Icon(Icons.message),
      ),
    );
  }
}