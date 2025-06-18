part of janus_client;

/// Minimal wrapper for a hypothetical Janus voice hub plugin.
/// This exposes basic registration and call methods
/// and allows closing the connection properly.
class JanusVoiceHubPlugin extends JanusPlugin {
  JanusVoiceHubPlugin({handleId, context, transport, session})
      : super(
            context: context,
            handleId: handleId,
            plugin: JanusPlugins.VOICE_HUB,
            session: session,
            transport: transport);

  /// Register a user on the voice hub plugin
  Future<void> register(String username) async {
    await send(data: {"request": "register", "username": username});
  }

  /// Start a call with [username].
  /// If [offer] is not supplied a default audio offer will be generated.
  Future<void> call(String username, {RTCSessionDescription? offer}) async {
    offer ??= await createOffer(audioRecv: true, videoRecv: false);
    await send(data: {"request": "call", "username": username}, jsep: offer);
  }

  /// Send a session update payload on the data channel.
  Future<void> sendSessionUpdate(Map<String, dynamic> session) async {
    await sendData(jsonEncode({"type": "session.update", "session": session}));
  }

  /// Hangup the call and clean resources.
  Future<void> hangup() async {
    await super.hangup();
    await send(data: {"request": "hangup"});
    dispose();
  }
}
