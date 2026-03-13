import 'platform_utils_stub.dart'
    if (dart.library.io) 'platform_utils_io.dart';

class PlatformUtils {
  static bool get isAndroid => PlatformUtilsImpl.isAndroid;
  static bool get isIOS => PlatformUtilsImpl.isIOS;
  static bool get isWindows => PlatformUtilsImpl.isWindows;
}
