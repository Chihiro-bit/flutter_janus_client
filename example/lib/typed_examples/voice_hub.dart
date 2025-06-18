import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/janus_client.dart';
import '../conf.dart';

class VoiceHubExample extends StatefulWidget {
  @override
  State<VoiceHubExample> createState() => _VoiceHubExampleState();
}

class _VoiceHubExampleState extends State<VoiceHubExample> {
  late JanusClient client;
  late WebSocketJanusTransport ws;
  JanusSession? session;
  JanusVoiceHubPlugin? plugin;
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initClient();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
  }

  Future<void> _initClient() async {
    ws = WebSocketJanusTransport(url: servermap['janus_ws']);
    client = JanusClient(
        transport: ws,
        iceServers: [
          RTCIceServer(urls: 'stun:stun.l.google.com:19302')
        ],
        isUnifiedPlan: true);
    session = await client.createSession();
    plugin = await session!.attach<JanusVoiceHubPlugin>();
    plugin!.remoteTrack?.listen((event) async {
      if (event.track != null && event.flowing == true) {
        MediaStream stream = await createLocalMediaStream(event.track!.id!);
        await stream.addTrack(event.track!);
        _remoteRenderer.srcObject = stream;
        if (kIsWeb) _remoteRenderer.muted = false;
      }
    });
  }

  Future<void> startCall() async {
    await plugin!.initializeMediaDevices(mediaConstraints: {'audio': true});
    _localRenderer.srcObject = plugin!.webRTCHandle?.localStream;
    await plugin!.register(nameController.text.isEmpty ? 'flutter_client' : nameController.text);
    var offer = await plugin!.createOffer(audioRecv: true, videoRecv: false);
    await plugin!.call(nameController.text.isEmpty ? 'flutter_client' : nameController.text, offer: offer);
  }

  Future<void> hangup() async {
    await plugin?.hangup();
    await session?.dispose();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Hub')),
      body: Column(
        children: [
          Expanded(
            child: RTCVideoView(_remoteRenderer, mirror: true),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(onPressed: startCall, child: const Text('Start')),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: hangup, child: const Text('Hangup')),
            ],
          ),
        ],
      ),
    );
  }
}
