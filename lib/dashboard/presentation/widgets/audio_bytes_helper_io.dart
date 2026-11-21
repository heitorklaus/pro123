import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readLocalAudioBytes(String path) async {
  return File(path).readAsBytes();
}
