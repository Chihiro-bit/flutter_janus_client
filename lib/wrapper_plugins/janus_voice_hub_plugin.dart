part of janus_client;

class JanusVoiceHubPlugin extends JanusPlugin {
  JanusVoiceHubPlugin({handleId, context, transport, session})
      : super(
            context: context,
            handleId: handleId,
            plugin: JanusPlugins.VOICE_HUB,
            session: session,
            transport: transport);

  Future<void> register(String username) async {
    var payload = {"request": "register", "username": username};
    await send(data: payload);
  }

  Future<void> call(String username, {RTCSessionDescription? offer}) async {
    var payload = {"request": "call", "username": username};
    offer ??=
        await createOffer(audioRecv: true, videoRecv: false, dataChannel: true);
    await send(data: payload, jsep: offer);
  }

  Future<void> updateSession(Map<String, dynamic> update) async {
    var data = {"type": "session.update", "session": update};
    await sendData(stringify(data));
  }

  @override
  Future<void> hangup() async {
    await super.hangup();
    await send(data: {"request": "hangup"});
  }
}
