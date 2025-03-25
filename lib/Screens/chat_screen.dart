// lib/screens/chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sampark/controller/chat_controller.dart'; // Adjust import path
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:sampark/widgets/custom_textfield.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key}); // No required parameters

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChatController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(controller.friendImage)),
            const SizedBox(width: 10),
            Text(controller.friendName),
          ],
        ),
        actions: [
          Obx(
            () => IconButton(
              icon: const Icon(Icons.call),
              onPressed: controller.inCall.value ? null : controller.startCall,
            ),
          ),
        ],
      ),
      body: Obx(
        () => controller.inCall.value ? _buildCallUI(controller) : _buildChatUI(controller),
      ),
    );
  }

  Widget _buildCallUI(ChatController controller) {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: rtc.RTCVideoView(controller.localRenderer)),
              Expanded(child: rtc.RTCVideoView(controller.remoteRenderer)),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: controller.endCall,
          child: const Text('End Call'),
        ),
      ],
    );
  }

  Widget _buildChatUI(ChatController controller) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user')
                .doc(controller.currentUser.uid)
                .collection('messages')
                .doc(controller.friendId)
                .collection('chats')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No messages yet'));
              }

              final messages = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final messageData = messages[index].data() as Map<String, dynamic>;
                  final isMe = messageData['senderId'] == controller.currentUser.uid;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.yellow[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(messageData['message']),
                    ),
                  );
                },
              );
            },
          ),
        ),
        CustomTextfield(controller),
      ],
    );
  }
}