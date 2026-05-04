import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

void main() {
  test('round-trips text and background colors through HTML', () {
    final document = quill.Document()
      ..insert(0, 'Hello')
      ..format(0, 5, quill.Attribute.fromKeyValue('color', '#ff0000')!)
      ..format(0, 5, quill.Attribute.fromKeyValue('background', '#00ff00')!);

    final deltaJson =
        List<Map<String, dynamic>>.from(document.toDelta().toJson());
    final html = QuillDeltaToHtmlConverter(
      deltaJson,
      ConverterOptions.forEmail(),
    ).convert();

    final parsedDelta = HtmlToDelta().convert(html);
    final parsedDocument = quill.Document.fromDelta(parsedDelta);
    final attrs = parsedDocument.toDelta().operations.first.attributes ?? {};

    expect(attrs['color'], '#ff0000');
    expect(attrs['background'], '#00ff00');
  });
}
