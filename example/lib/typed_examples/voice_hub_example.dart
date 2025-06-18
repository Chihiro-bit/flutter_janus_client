import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dio/dio.dart';
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
  WebSocket? _lifecycleWs;
  final Dio _dio = Dio();

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
    // Step 1: request conversation details from backend.
    final conv = await _dio.post('${servermap['api_base']}/ai_create_conversation');
    final convData = conv.data['data'];
    final userId = convData['user_id'];
    final threadId = convData['thread_id'];

    // Step 2: obtain STUN/TURN servers from backend.
    final iceRes = await _dio.get('${servermap['api_base']}/ai_ice_servers');
    final iceList = List<Map<String, dynamic>>.from(iceRes.data['data']);
    final iceServers = iceList
        .map((e) => RTCIceServer(
            urls: e['urls'],
            username: e['username'],
            credential: e['credential']))
        .toList();

    // Step 3: create Janus session and attach plugin.
    _transport = WebSocketJanusTransport(url: servermap['janus_ws']);
    _client = JanusClient(
      transport: _transport!,
      isUnifiedPlan: true,
      iceServers: iceServers,
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

    // Step 4: open lifecycle WebSocket.
    final wsUrl =
        '${servermap['api_ws']}/realtime/webrtc_lifecycle?user_id=$userId&assistant_id=${servermap['assistant_id']}&thread_id=$threadId';
    _lifecycleWs = await WebSocket.connect(wsUrl);
    _lifecycleWs!.listen(_onWsMessage, onDone: _stop);

    // Step 5: register and start call on the voice hub plugin.
    String user = const Uuid().v4();
    await _plugin!.register(user);
    var offer = await _plugin!.createOffer(audioRecv: true, videoRecv: false);
    await _plugin!.call(user, offer: offer);
    setState(() => _inCall = true);
  }

  void _onWsMessage(dynamic data) async {
    final msg = jsonDecode(data as String);
    final type = msg['type'];
    final options = msg['options'];
    if (type == 'message' && options == 2 && msg['ready'] == true) {
      await _plugin?.sendSessionUpdate({
        'instructions': 'hello from flutter',
        'voice': 'alloy',
        'input_audio_transcription': null,
      });
    }
    if (type == 'hangup') {
      _stop();
    }
  }

  Future<void> _stop() async {
    await _plugin?.hangup();
    await _session?.dispose();
    await _transport?.dispose();
    await _lifecycleWs?.close();
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
