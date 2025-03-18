
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class CustomTextfield extends StatefulWidget {
  final String userId;
  final String friendId;

  const CustomTextfield(this.userId, this.friendId, {super.key});

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type your message here...',
                  fillColor: Colors.grey[200],
                  filled: true,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(width: 0, color: Colors.white),
                    borderRadius: BorderRadius.circular(26),
                    gapPadding: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
              ),
              onTap: () async {
                String message = _controller.text.trim();
                if (message.isEmpty) return; // Prevent sending empty messages
                _controller.clear();

                // Add the message to the sender's chats collection
                await FirebaseFirestore.instance
                    .collection('user')
                    .doc(widget.userId)
                    .collection('messages')
                    .doc(widget.friendId)
                    .collection('chats')
                    .add({
                  "senderId": widget.userId,
                  "reciverId": widget.friendId, // Fix typo: receiverId
                  "message": message,
                  "type": "text", // Use a meaningful type instead of "type"
                  "date": DateTime.now(),
                });

                // Update last message for sender
                await FirebaseFirestore.instance
                    .collection('user') // Fix typo: 'users' -> 'user' to match your structure
                    .doc(widget.userId)
                    .collection('messages')
                    .doc(widget.friendId)
                    .set({
                  'last_msg': message,
                  'date': DateTime.now(), // Optional: for sorting
                }, SetOptions(merge: true));

                // Add the message to the receiver's chats collection
                await FirebaseFirestore.instance
                    .collection('user')
                    .doc(widget.friendId)
                    .collection('messages')
                    .doc(widget.userId)
                    .collection('chats')
                    .add({
                  "senderId": widget.userId,
                  "reciverId": widget.friendId, // Fix typo: receiverId
                  "message": message,
                  "type": "text",
                  "date": DateTime.now(),
                });

                // Update last message for receiver
                await FirebaseFirestore.instance
                    .collection('user')
                    .doc(widget.friendId)
                    .collection('messages')
                    .doc(widget.userId)
                    .set({
                  'last_msg': message,
                  'date': DateTime.now(), // Optional: for sorting
                }, SetOptions(merge: true));
              },
            ),
          ],
        ),
      ),
    );
  }
}