import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// TCP congestion controls the mips stack registers (mipstack), cubic
/// first as its default.
const tunCongestionControllers = ['cubic', 'reno', 'bbr', 'bbr3'];

/// The `congestion-controller` key of the TUN patch: set only for the mips
/// stack and only when the user picked one, so a profile's own value and
/// the other stacks stay untouched.
Map<String, dynamic> tunCongestionPatch(Tun tun) {
  final value = tun.congestionController;
  if (tun.stack != TunStack.mips || value == null) return const {};
  return {'congestion-controller': value};
}
