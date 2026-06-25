import 'package:connectivity_plus/connectivity_plus.dart';

/// Why a request to the backend couldn't go through. Used to tailor the
/// message on the connection screen / popup.
enum ConnReason {
  /// A VPN is active. Using a VPN is the user's choice and is never blocked —
  /// but when a request fails it's a likely cause, so we gently suggest the app
  /// works better without one.
  vpn,

  /// The device has no network at all.
  offline,

  /// We have a normal network but still couldn't reach the service.
  generic,
}

/// Inspects the device's connectivity to explain a failed backend call.
///
/// VPN takes priority: on phones a VPN often routes around the service, so when
/// one is active and a request failed we surface a gentle "works better without
/// a VPN" hint (the user is free to keep it on). Falls back to
/// [ConnReason.offline] when there's no link, and [ConnReason.generic]
/// otherwise (the server itself is likely down).
Future<ConnReason> diagnoseConnection() async {
  List<ConnectivityResult> results;
  try {
    results = await Connectivity().checkConnectivity();
  } catch (_) {
    return ConnReason.generic;
  }
  if (results.contains(ConnectivityResult.vpn)) return ConnReason.vpn;
  if (results.isEmpty ||
      results.every((r) => r == ConnectivityResult.none)) {
    return ConnReason.offline;
  }
  return ConnReason.generic;
}
