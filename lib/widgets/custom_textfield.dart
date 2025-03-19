import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomTextfield extends StatefulWidget {
  final String userId;
  final String friendId;

  const CustomTextfield(this.userId, this.friendId, {super.key});

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  TextEditingController _controller = TextEditingController();

  Future<void> _sendMessage(String message, String type) async {
    if (message.isEmpty) return;
    _controller.clear();
    await _addMessageToFirestore(message, type);
  }

  Future<void> _addMessageToFirestore(String content, String type) async {
    try {
      print('Sending message from ${widget.userId} to ${widget.friendId}');
      // Sender's chat
      await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .collection('messages')
          .doc(widget.friendId)
          .collection('chats')
          .add({
        "senderId": widget.userId,
        "receiverId": widget.friendId,
        "message": content,
        "type": type,
        "date": DateTime.now(),
      });

      await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .collection('messages')
          .doc(widget.friendId)
          .set({
        'last_msg': content,
        'date': DateTime.now(),
      }, SetOptions(merge: true));

      // Receiver's chat
      await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.friendId)
          .collection('messages')
          .doc(widget.userId)
          .collection('chats')
          .add({
        "senderId": widget.userId,
        "receiverId": widget.friendId,
        "message": content,
        "type": type,
        "date": DateTime.now(),
      });

      await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.friendId)
          .collection('messages')
          .doc(widget.userId)
          .set({
        'last_msg': content,
        'date': DateTime.now(),
      }, SetOptions(merge: true));

      print('Message sent successfully');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

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
                child: const Icon(Icons.send, color: Colors.white),
              ),
              onTap: () async {
                try {
                  await _sendMessage(_controller.text, 'text');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send message: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}