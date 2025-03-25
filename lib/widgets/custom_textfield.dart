import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sampark/controller/chat_controller.dart';
class CustomTextfield extends StatelessWidget {
  final ChatController controller;
  const CustomTextfield(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: 'Type your message here...',
                  fillColor: Colors.grey[200],
                  filled: true,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(width: 0, color: Colors.white),
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                try {
                  await controller.sendMessage(textController.text, 'text');
                  textController.clear();
                } catch (e) {
                  Get.snackbar('Error', 'Failed to send message: $e');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}