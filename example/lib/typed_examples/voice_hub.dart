import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/janus_client.dart';
import '../conf.dart';

class VoiceHubExample extends StatefulWidget {
  @override
  State<VoiceHubExample> createState() => _VoiceHubExampleState();
}

class _VoiceHubExampleState extends State<VoiceHubExample> {
  JanusClient? client;
  WebSocketJanusTransport? ws;
  JanusSession? session;
  JanusVoiceHubPlugin? plugin;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool connected = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  Future<void> connect() async {
    ws = WebSocketJanusTransport(url: servermap['janus_ws']);
    client = JanusClient(
        transport: ws!,
        iceServers: [RTCIceServer(urls: 'stun:stun.l.google.com:19302')],
        isUnifiedPlan: true);
    session = await client!.createSession();
    plugin = await session!.attach<JanusVoiceHubPlugin>();
    _localStream = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
    await plugin!.initializeMediaDevices();
    plugin!.remoteTrack?.listen((event) {
      if (event.track != null && event.flowing == true) {
        _remoteStream ??= MediaStream();
        _remoteStream!.addTrack(event.track!);
        _remoteRenderer.srcObject = _remoteStream;
      }
    });
    await plugin!.register('flutter_client');
    await plugin!.call('server');
    setState(() {
      connected = true;
    });
  }

  Future<void> disconnect() async {
    await plugin?.hangup();
    await session?.dispose();
    ws?.dispose();
    await _remoteRenderer.dispose();
    await _localStream?.dispose();
    setState(() {
      connected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Voice Hub Example')),
      body: Column(
        children: [
          Expanded(
              child: RTCVideoView(_remoteRenderer, mirror: false)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: connected ? null : connect, child: Text('Connect')),
              SizedBox(width: 20),
              ElevatedButton(
                  onPressed: connected ? disconnect : null,
                  child: Text('Hangup')),
            ],
          )
        ],
      ),
    );
  }
}
