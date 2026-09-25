import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> fetchWebImageBytes(String url) async {
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty) return null;

  try {
    final completer = Completer<Uint8List?>();
    final img = html.ImageElement();
    img.crossOrigin = 'anonymous';

    img.onLoad.listen((_) {
      try {
        final canvas = html.CanvasElement(width: img.naturalWidth, height: img.naturalHeight);
        final ctx = canvas.context2D;
        ctx.drawImage(img, 0, 0);
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.90);
        if (dataUrl.contains(',')) {
          completer.complete(base64Decode(dataUrl.split(',').last));
        } else {
          completer.complete(null);
        }
      } catch (e) {
        completer.complete(null);
      }
    });

    img.onError.listen((e) {
      completer.complete(null);
    });

    img.src = cleanUrl;
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
  } catch (_) {
    return null;
  }
}
