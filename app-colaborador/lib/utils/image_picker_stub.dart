import 'dart:typed_data';

class PickedFileResult {
  final String name;
  final int size;
  final Uint8List bytes;
  PickedFileResult({required this.name, required this.size, required this.bytes});
}

Future<PickedFileResult?> pickImage() async {
  return null;
}
