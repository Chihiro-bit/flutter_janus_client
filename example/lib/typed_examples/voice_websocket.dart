import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/janus_client.dart';

import '../conf.dart';

class VoiceWebSocketExample extends StatefulWidget {
  const VoiceWebSocketExample({Key? key}) : super(key: key);

  @override
  State<VoiceWebSocketExample> createState() => _VoiceWebSocketExampleState();
}

class _VoiceWebSocketExampleState extends State<VoiceWebSocketExample> {
  JanusClient? _client;
  WebSocketJanusTransport? _transport;
  JanusSession? _session;
  JanusAudioBridgePlugin? _audioHandle;

  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _remoteStream;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  Future<void> _connect() async {
    _transport = WebSocketJanusTransport(url: servermap['janus_ws']);
    _client = JanusClient(
      transport: _transport!,
      isUnifiedPlan: true,
      iceServers: [
        RTCIceServer(urls: 'stun:stun.l.google.com:19302'),
      ],
    );

    _session = await _client!.createSession();
    _audioHandle = await _session!.attach<JanusAudioBridgePlugin>();

    await _audioHandle!.initializeMediaDevices(mediaConstraints: {
      'audio': true,
      'video': false,
    });

    _audioHandle!.remoteTrack?.listen((event) async {
      if (event.track != null && event.flowing == true) {
        _remoteStream ??= await createLocalMediaStream('remote');
        await _remoteStream!.addTrack(event.track!);
        _remoteRenderer.srcObject = _remoteStream;
        if (kIsWeb) {
          _remoteRenderer.muted = false;
        }
      }
    });

    await _audioHandle!.joinRoom(1234, display: 'flutter_user');

    setState(() {
      _connected = true;
    });
  }

  Future<void> _hangup() async {
    await _audioHandle?.hangup();
    await _audioHandle?.dispose();
    await _session?.dispose();
    await _transport?.dispose();

    stopAllTracks(_remoteStream);
    _remoteRenderer.srcObject = null;
    _remoteStream = null;

    setState(() {
      _connected = false;
    });
  }

  @override
  void dispose() {
    _hangup();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice WebSocket'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: RTCVideoView(_remoteRenderer)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _connected ? null : _connect,
                child: const Text('Connect'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _connected ? _hangup : null,
                child: const Text('Hangup'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
