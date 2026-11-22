/// How long the core gets to confirm that its listeners are down. It
/// answers in milliseconds when it works; past this it is stuck.
const coreStopConfirmTimeout = Duration(seconds: 10);

/// Windows stops the proxy the way Clash Verge does: the helper ends the
/// core process, which takes its TUN adapter and routes down with it, and a
/// fresh core without listeners takes its place for the UI. Closing the TUN
/// inside a running core could hang and leave the proxy on. Android owns
/// its session natively, other desktops close the listeners in place.
bool stopByReplacingCore({required bool isWindows}) => isWindows;
