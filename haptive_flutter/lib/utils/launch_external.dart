import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternalUri(Uri uri) {
  if (kIsWeb && uri.scheme == 'tel') {
    return Future.value(false);
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
