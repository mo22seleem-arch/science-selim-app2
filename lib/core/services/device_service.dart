import 'native_bridge.dart';

class DeviceInfo { final String id, name; const DeviceInfo(this.id, this.name); }

class DeviceService {
  static DeviceInfo? _cached;
  /// ANDROID_ID: stable per device + app-signing key (changes only on factory reset).
  static Future<DeviceInfo> info() async {
    if (_cached != null) return _cached!;
    final d = await NativeBridge.deviceInfo();
    return _cached = DeviceInfo(d.id, d.name);
  }
}
