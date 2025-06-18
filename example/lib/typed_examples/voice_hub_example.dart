import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/janus_client.dart';
import 'package:uuid/uuid.dart';
import '../conf.dart';

class VoiceHubExample extends StatefulWidget {
  const VoiceHubExample({super.key});

  @override
  State<VoiceHubExample> createState() => _VoiceHubExampleState();
}

class _VoiceHubExampleState extends State<VoiceHubExample> {
  JanusClient? _client;
  JanusSession? _session;
  JanusVoiceHubPlugin? _plugin;
  WebSocketJanusTransport? _transport;
  final Dio _dio = Dio();
  WebSocket? _lifecycleSocket;

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  Future<void> _start() async {
    try {
      final conv = await _dio.post('${servermap['backend']}/ai_create_conversation');
      final data = conv.data['data'];
      final userId = data['user_id'];
      final threadId = data['thread_id'];

      final iceRes = await _dio.get('${servermap['backend']}/ai_ice_servers');
      final serverList = (iceRes.data['data'] as List?) ?? [];
      final ice = serverList
          .map<RTCIceServer>((e) => RTCIceServer(
                urls: e['urls'],
                username: e['username'],
                credential: e['credential'],
              ))
          .toList();

      _lifecycleSocket = await WebSocket.connect(
          '${servermap['socket']}/realtime/webrtc_lifecycle?user_id=$userId&assistant_id=demo&thread_id=$threadId');

      _transport = WebSocketJanusTransport(url: servermap['janus_ws']);
      _client = JanusClient(
        transport: _transport!,
        isUnifiedPlan: true,
        iceServers: ice.isNotEmpty
            ? ice
            : [RTCIceServer(urls: 'stun:stun.l.google.com:19302')],
      );
      _session = await _client!.createSession();
      _plugin = await _session!.attach<JanusVoiceHubPlugin>();
      await _plugin!.initializeMediaDevices(mediaConstraints: {
        'audio': true,
        'video': false,
      });
      _localStream = _plugin!.webRTCHandle?.localStream;
      _plugin!.remoteTrack?.listen((event) async {
        if (event.track != null && event.flowing == true) {
          _remoteStream ??= await createLocalMediaStream('remote');
          _remoteStream!.addTrack(event.track!);
          _remoteRenderer.srcObject = _remoteStream;
          setState(() {});
        }
      });
      String user = const Uuid().v4();
      await _plugin!.register(user);
      var offer = await _plugin!.createOffer(audioRecv: true, videoRecv: false);
      await _plugin!.call(user, offer: offer);
      setState(() {
        _inCall = true;
      });
    } catch (e) {
      debugPrint('error starting voice hub: $e');
    }
  }

  Future<void> _stop() async {
    await _plugin?.hangup();
    await _session?.dispose();
    await _transport?.dispose();
    await _lifecycleSocket?.close();
    await _remoteRenderer.dispose();
    setState(() {
      _inCall = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Hub Example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _inCall ? null : _start,
              child: const Text('Connect'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _inCall ? _stop : null,
              child: const Text('Hangup'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
