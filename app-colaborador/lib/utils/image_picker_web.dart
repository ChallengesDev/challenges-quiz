export 'image_picker_stub.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'image_picker_stub.dart';

Future<PickedFileResult?> pickImage() async {
  final completer = Completer<PickedFileResult?>();
  final input = html.InputElement(type: 'file');
  input.accept = 'image/png, image/jpeg, image/jpg';
  
  input.onChange.listen((event) {
    if (input.files == null || input.files!.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = input.files!.first;
    final reader = html.FileReader();
    
    reader.onLoadEnd.listen((e) {
      final bytes = reader.result as Uint8List;
      completer.complete(PickedFileResult(
        name: file.name,
        size: file.size,
        bytes: bytes,
      ));
    });
    
    reader.readAsArrayBuffer(file);
  });
  
  input.click();
  return completer.future;
}
