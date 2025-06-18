part of janus_client;

class JanusVoiceHubPlugin extends JanusPlugin {
  JanusVoiceHubPlugin({handleId, context, transport, session})
      : super(
            context: context,
            handleId: handleId,
            plugin: JanusPlugins.VOICE_HUB,
            session: session,
            transport: transport);

  Future<void> register(String userName) async {
    await send(data: {"request": "register", "username": userName});
  }

  Future<void> call(String userName, {RTCSessionDescription? offer}) async {
    if (offer == null) {
      offer = await createOffer(audioRecv: true, videoRecv: false);
    }
    await send(data: {"request": "call", "username": userName}, jsep: offer);
  }

  Future<void> updateSession(Map<String, dynamic> session) async {
    await send(data: {"type": "session.update", "session": session});
  }

  @override
  Future<void> hangup() async {
    await super.hangup();
    await send(data: {"request": "hangup"});
    dispose();
  }
}
