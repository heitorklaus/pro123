import 'dart:typed_data';
import 'web_image_loader_stub.dart'
    if (dart.library.html) 'web_image_loader_web.dart';

Future<Uint8List?> getWebImageBytes(String url) => fetchWebImageBytes(url);
