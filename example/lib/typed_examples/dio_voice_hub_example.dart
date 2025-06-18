import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/janus_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import '../conf.dart';

class DioVoiceHubExample extends StatefulWidget {
  const DioVoiceHubExample({super.key});

  @override
  State<DioVoiceHubExample> createState() => _DioVoiceHubExampleState();
}

class _DioVoiceHubExampleState extends State<DioVoiceHubExample> {
  JanusClient? _client;
  JanusSession? _session;
  JanusVoiceHubPlugin? _plugin;
  WebSocketJanusTransport? _transport;
  WebSocketChannel? _lifecycleSocket;

  MediaStream? _remoteStream;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  Future<void> _start() async {
    final dio = Dio();
    final threads = await dio.get('${servermap['backend_api']}/conversation');
    if (threads.statusCode != 200) return;
    final userId = threads.data['data']['user_id'];
    final threadId = threads.data['data']['thread_id'];

    final iceRes = await dio.get('${servermap['backend_api']}/ice_servers');
    List iceServers = iceRes.statusCode == 200 ? iceRes.data['data'] : [];
    final servers = iceServers
        .map<RTCIceServer>((e) => RTCIceServer(
              urls: e['urls'],
              username: e['username'],
              credential: e['credential'],
            ))
        .toList();

    _lifecycleSocket = WebSocketChannel.connect(Uri.parse(
        '${servermap['backend_ws']}/realtime/webrtc_lifecycle?user_id=$userId&assistant_id=1&thread_id=$threadId'));

    _transport = WebSocketJanusTransport(url: servermap['janus_ws']);
    _client = JanusClient(
      transport: _transport!,
      isUnifiedPlan: true,
      iceServers: servers,
    );
    _session = await _client!.createSession();
    _plugin = await _session!.attach<JanusVoiceHubPlugin>();
    await _plugin!.initializeMediaDevices(mediaConstraints: {
      'audio': true,
      'video': false,
    });
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
    setState(() => _connected = true);
  }

  Future<void> _stop() async {
    await _plugin?.hangup();
    await _session?.dispose();
    await _transport?.dispose();
    await _remoteRenderer.dispose();
    await _lifecycleSocket?.sink.close();
    setState(() => _connected = false);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dio Voice Hub')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _connected ? null : _start,
              child: const Text('Connect'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _connected ? _stop : null,
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

