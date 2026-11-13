import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfo { final String id, name; const DeviceInfo(this.id, this.name); }

class DeviceService {
  static DeviceInfo? _cached;
  /// ANDROID_ID: stable per device + app-signing key (changes only on factory reset).
  static Future<DeviceInfo> info() async {
    if (_cached != null) return _cached!;
    final a = await const AndroidId().getId();
    final d = await DeviceInfoPlugin().androidInfo;
    return _cached = DeviceInfo(a ?? d.id, '${d.manufacturer} ${d.model}');
  }
}
