import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sampark/model/user_model.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sampark/widgets/custom_textfield.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final UserModel currentUser;
  final String friensId;
  final String friendName;
  final String friendimage;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.friensId,
    required this.friendName,
    required this.friendimage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCall = false;
  String? _currentCallId;
  StreamSubscription<QuerySnapshot>? _callListener;
  StreamSubscription<QuerySnapshot>? _iceCandidateListener;
  StreamSubscription<DocumentSnapshot>? _callStatusListener;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _listenForCall();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<bool> _requestPermissions() async {
    print('Requesting microphone permission...');
    var status = await Permission.microphone.status;
    print('Current microphone permission status: $status');
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      print('Requested microphone permission, new status: $status');
    }
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied. Calls won’t work.')),
      );
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
        print('ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call connection failed')),
          );
          _endCall();
        }
      };

      _peerConnection!.onTrack = (event) {
        print('Remote stream received');
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
          });
        }
      };

      _peerConnection!.onIceCandidate = (candidate) {
        print('ICE Candidate generated: ${candidate.candidate}');
        if (_currentCallId != null) {
          _sendIceCandidate(candidate, _currentCallId!);
        }
      };

      print('Requesting microphone access...');
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      print('Microphone access granted');
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      _localRenderer.srcObject = _localStream;
    }

    if (remoteOffer != null) {
      await _peerConnection!.setRemoteDescription(remoteOffer);
      print('Remote offer set: ${remoteOffer.sdp}');
    }
  }

  Future<void> _startCall() async {
    print('Starting call...');
    await _setupWebRTC();
    if (_peerConnection == null || _localStream == null) {
      print('WebRTC setup failed, aborting call');
      return;
    }

    _currentCallId = const Uuid().v4();
    try {
      var offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      print('Offer created and set: ${offer.sdp}');

      await FirebaseFirestore.instance.collection('calls').doc(_currentCallId).set({
        'callerId': widget.currentUser.uid,
        'receiverId': widget.friensId,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
        'status': 'ringing',
      });
      print('Call document created in Firestore');

      _callStatusListener = FirebaseFirestore.instance
          .collection('calls')
          .doc(_currentCallId)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          var data = snapshot.data()!;
          print('Call status updated: ${data['status']}');
          if (data['status'] == 'accepted' && data['answer'] != null) {
            await _peerConnection!.setRemoteDescription(
              RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
            );
            print('Answer set as remote description');
            setState(() => _inCall = true);
          } else if (data['status'] == 'rejected' || data['status'] == 'ended') {
            print('Call ${data['status']} by other party');
            _endCall();
          }
        } else {
          print('Call document deleted, ending call');
          _endCall();
        }
      });

      _listenForIceCandidates(_currentCallId!);
    } catch (e) {
      print('Error starting call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start call: $e')),
      );
    }
  }

  Future<void> _listenForCall() async {
    _callListener = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: widget.currentUser.uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && !_inCall) {
        var callDoc = snapshot.docs.first;
        _currentCallId = callDoc.id;
        var data = callDoc.data();
        print('Incoming call detected: $_currentCallId');

        bool? accept = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Incoming Call from ${widget.friendName}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Reject'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Accept'),
              ),
            ],
          ),
        );

        if (accept == true) {
          await _setupWebRTC(remoteOffer: RTCSessionDescription(data['offer']['sdp'], data['offer']['type']));
          if (_peerConnection == null || _localStream == null) {
            print('WebRTC setup failed for receiver');
            return;
          }

          try {
            var answer = await _peerConnection!.createAnswer();
            await _peerConnection!.setLocalDescription(answer);
            print('Answer created and set: ${answer.sdp}');

            await FirebaseFirestore.instance.collection('calls').doc(_currentCallId).update({
              'answer': {'sdp': answer.sdp, 'type': answer.type},
              'status': 'accepted',
            });
            print('Call accepted and updated in Firestore');

            setState(() => _inCall = true);
            _listenForIceCandidates(_currentCallId!);

            _callStatusListener = FirebaseFirestore.instance
                .collection('calls')
                .doc(_currentCallId)
                .snapshots()
                .listen((snapshot) async {
              if (snapshot.exists) {
                var data = snapshot.data()!;
                if (data['status'] == 'ended') {
                  print('Call ended by other party');
                  _endCall();
                }
              } else {
                print('Call document deleted, ending call');
                _endCall();
              }
            });
          } catch (e) {
            print('Error accepting call: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to accept call: $e')),
            );
          }
        } else {
          await FirebaseFirestore.instance.collection('calls').doc(_currentCallId).update({
            'status': 'rejected',
          });
          print('Call rejected');
          _endCall();
        }
      }
    });
  }

  void _sendIceCandidate(RTCIceCandidate candidate, String callId) {
    FirebaseFirestore.instance.collection('calls').doc(callId).collection('iceCandidates').add({
      'candidate': candidate.toMap(),
      'senderId': widget.currentUser.uid,
    }).then((_) => print('ICE candidate sent')).catchError((e) => print('Error sending ICE candidate: $e'));
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
          if (data['senderId'] != widget.currentUser.uid) {
            print('Adding remote ICE candidate: ${data['candidate']['candidate']}');
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

  Future<void> _endCall() async {
    print('Ending call...');
    try {
      // Signal call end to other party
      if (_currentCallId != null) {
        try {
          await FirebaseFirestore.instance.collection('calls').doc(_currentCallId).update({
            'status': 'ended',
          });
          print('Call status set to ended');
        } catch (e) {
          print('Failed to set call status to ended: $e');
          // Continue cleanup even if update fails
        }
      }

      // Cancel all Firestore listeners
      await _callListener?.cancel();
      await _iceCandidateListener?.cancel();
      await _callStatusListener?.cancel();
      print('All Firestore listeners canceled');

      // Close peer connection
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
        print('Peer connection closed');
      }

      // Stop and dispose local stream
      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
        print('Local stream stopped and disposed');
      }

      // Clear renderers
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      print('Renderers cleared');

      // Delete call document from Firestore
      if (_currentCallId != null) {
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          await FirebaseFirestore.instance.collection('calls').doc(_currentCallId).delete();
          print('Call document deleted');
        } catch (e) {
          print('Failed to delete call document: $e');
          // Continue cleanup even if delete fails
        }
        _currentCallId = null;
      }

      // Update UI state
      if (mounted) {
        setState(() {
          _inCall = false;
        });
        print('UI state updated: _inCall = false');
      }

      // Add delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 300));

      // Force a rebuild if still mounted
      if (mounted) {
        setState(() {});
        print('Forced UI rebuild');
      }
    } catch (e) {
      print('Error ending call: $e');
      if (mounted && !e.toString().contains('permission-denied')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end call cleanly: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    print('Disposing ChatScreen...');
    _callListener?.cancel();
    _iceCandidateListener?.cancel();
    _callStatusListener?.cancel();
    _peerConnection?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building UI, _inCall: $_inCall');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(widget.friendimage)),
            const SizedBox(width: 10),
            Text(widget.friendName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _inCall ? null : _startCall,
          ),
        ],
      ),
      body: _inCall ? _buildCallUI() : _buildChatUI(),
    );
  }

  Widget _buildCallUI() {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: RTCVideoView(_localRenderer)),
              Expanded(child: RTCVideoView(_remoteRenderer)),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _endCall,
          child: const Text('End Call'),
        ),
      ],
    );
  }

  Widget _buildChatUI() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user')
                .doc(widget.currentUser.uid)
                .collection('messages')
                .doc(widget.friensId)
                .collection('chats')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
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
                  final isMe = messageData['senderId'] == widget.currentUser.uid;
                  final messageContent = messageData['message'] as String;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.yellow[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(messageContent),
                    ),
                  );
                },
              );
            },
          ),
        ),
        CustomTextfield(widget.currentUser.uid, widget.friensId),
      ],
    );
  }
}