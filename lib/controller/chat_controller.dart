import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sampark/controller/auth_controller.dart'; // Should be auth_controller.dart
import 'package:sampark/model/user_model.dart';
import 'package:uuid/uuid.dart';

class ChatController extends GetxController {
  final UserModel currentUser = Get.find<AuthController>().currentUser.value!;
  final String friendId = Get.arguments['friendId'] ?? '';
  final String friendName = Get.arguments['friendName'] ?? 'Unknown';
  final String friendImage = Get.arguments['friendImage'] ?? '';

  RxBool inCall = false.obs;
  RxString currentCallId = ''.obs;
  rtc.RTCPeerConnection? _peerConnection;
  rtc.MediaStream? _localStream;
  final rtc.RTCVideoRenderer localRenderer = rtc.RTCVideoRenderer();
  final rtc.RTCVideoRenderer remoteRenderer = rtc.RTCVideoRenderer();
  StreamSubscription<QuerySnapshot>? _callListener;
  StreamSubscription<QuerySnapshot>? _iceCandidateListener;
  StreamSubscription<DocumentSnapshot>? _callStatusListener;

  @override
  void onInit() {
    super.onInit();
    _initRenderers();
    _listenForCall();
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<bool> _requestPermissions() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (!status.isGranted) {
      Get.snackbar('Permission Denied', 'Microphone permission denied.');
      return false;
    }
    return true;
  }

  Future<void> _setupWebRTC({RTCSessionDescription? remoteOffer}) async {
    if (!await _requestPermissions()) return;

    if (_peerConnection == null) {
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);
      _peerConnection!.onIceConnectionState = (state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          Get.snackbar('Call Failed', 'Call connection failed');
          endCall();
        }
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          update();
        }
      };

      _peerConnection!.onIceCandidate = (candidate) {
        if (currentCallId.value.isNotEmpty) {
          _sendIceCandidate(candidate, currentCallId.value);
        }
      };

      _localStream = await rtc.navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      localRenderer.srcObject = _localStream;
    }

    if (remoteOffer != null) {
      await _peerConnection!.setRemoteDescription(remoteOffer);
    }
  }

  Future<void> startCall() async {
    await _setupWebRTC();
    if (_peerConnection == null || _localStream == null) return;

    currentCallId.value = const Uuid().v4();
    var offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await FirebaseFirestore.instance.collection('calls').doc(currentCallId.value).set({
      'callerId': currentUser.uid,
      'receiverId': friendId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'status': 'ringing',
    });

    _callStatusListener = FirebaseFirestore.instance
        .collection('calls')
        .doc(currentCallId.value)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        if (data['status'] == 'accepted' && data['answer'] != null) {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
          );
          inCall.value = true;
        } else if (data['status'] == 'rejected' || data['status'] == 'ended') {
          endCall();
        }
      } else {
        endCall();
      }
    });

    _listenForIceCandidates(currentCallId.value);
  }

  Future<void> _listenForCall() async {
    _callListener = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && !inCall.value) {
        var callDoc = snapshot.docs.first;
        currentCallId.value = callDoc.id;
        var data = callDoc.data();

        bool? accept = await Get.dialog<bool>(
          AlertDialog(
            title: Text('Incoming Call from $friendName'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Reject'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Accept'),
              ),
            ],
          ),
        );

        if (accept == true) {
          await _setupWebRTC(remoteOffer: RTCSessionDescription(data['offer']['sdp'], data['offer']['type']));
          if (_peerConnection == null || _localStream == null) return;

          var answer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(answer);

          await FirebaseFirestore.instance.collection('calls').doc(currentCallId.value).update({
            'answer': {'sdp': answer.sdp, 'type': answer.type},
            'status': 'accepted',
          });

          inCall.value = true;
          _listenForIceCandidates(currentCallId.value);

          _callStatusListener = FirebaseFirestore.instance
              .collection('calls')
              .doc(currentCallId.value)
              .snapshots()
              .listen((snapshot) async {
            if (snapshot.exists && snapshot.data()!['status'] == 'ended') {
              endCall();
            } else if (!snapshot.exists) {
              endCall();
            }
          });
        } else {
          await FirebaseFirestore.instance.collection('calls').doc(currentCallId.value).update({
            'status': 'rejected',
          });
          endCall();
        }
      }
    });
  }

  void _sendIceCandidate(RTCIceCandidate candidate, String callId) {
    FirebaseFirestore.instance.collection('calls').doc(callId).collection('iceCandidates').add({
      'candidate': candidate.toMap(),
      'senderId': currentUser.uid,
    });
  }

  void _listenForIceCandidates(String callId) {
    _iceCandidateListener = FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .collection('iceCandidates')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          var data = doc.doc.data()!;
          if (data['senderId'] != currentUser.uid) {
            _peerConnection!.addCandidate(RTCIceCandidate(
              data['candidate']['candidate'],
              data['candidate']['sdpMid'],
              data['candidate']['sdpMLineIndex'],
            ));
          }
        }
      }
    });
  }

  Future<void> endCall() async {
    if (currentCallId.value.isNotEmpty) {
      await FirebaseFirestore.instance.collection('calls').doc(currentCallId.value).update({
        'status': 'ended',
      }).catchError((e) => print('Error signaling call end: $e'));
    }

    await _callListener?.cancel();
    await _iceCandidateListener?.cancel();
    await _callStatusListener?.cancel();

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    if (currentCallId.value.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 200));
      await FirebaseFirestore.instance.collection('calls').doc(currentCallId.value).delete().catchError((e) => print('Error deleting call document: $e'));
      currentCallId.value = '';
    }

    inCall.value = false;
  }

  Future<void> sendMessage(String message, String type) async {
    if (message.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('user')
        .doc(currentUser.uid)
        .collection('messages')
        .doc(friendId)
        .collection('chats')
        .add({
      "senderId": currentUser.uid,
      "receiverId": friendId,
      "message": message,
      "type": type,
      "date": DateTime.now(),
    });

    await FirebaseFirestore.instance
        .collection('user')
        .doc(currentUser.uid)
        .collection('messages')
        .doc(friendId)
        .set({
      'last_msg': message,
      'date': DateTime.now(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('user')
        .doc(friendId)
        .collection('messages')
        .doc(currentUser.uid)
        .collection('chats')
        .add({
      "senderId": currentUser.uid,
      "receiverId": friendId,
      "message": message,
      "type": type,
      "date": DateTime.now(),
    });

    await FirebaseFirestore.instance
        .collection('user')
        .doc(friendId)
        .collection('messages')
        .doc(currentUser.uid)
        .set({
      'last_msg': message,
      'date': DateTime.now(),
    }, SetOptions(merge: true));
  }

  @override
  void onClose() {
    _callListener?.cancel();
    _iceCandidateListener?.cancel();
    _callStatusListener?.cancel();
    _peerConnection?.close();
    _localStream?.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.onClose();
  }
}