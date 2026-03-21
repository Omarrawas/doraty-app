import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      
      // Replace List<Map<String, dynamic>>.from(...) with SafeParser.safeMapList(...)
      final regex = RegExp(r'List\s*<\s*Map\s*<\s*String\s*,\s*dynamic\s*>\s*>\s*\.\s*from\s*\(');
      final newContent = content.replaceAll(regex, 'SafeParser.safeMapList(');
      
      if (newContent != content) {
        String finalContent = newContent;
        if (!finalContent.contains('safe_parser.dart')) {
          final lines = finalContent.split('\n');
          // Find last import
          int lastImport = -1;
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].trim().startsWith('import ')) {
              lastImport = i;
            }
          }
          final importStmt = "import 'package:doraty/core/utils/safe_parser.dart';";
          if (lastImport != -1) {
            lines.insert(lastImport + 1, importStmt);
          } else {
            lines.insert(0, importStmt);
          }
          finalContent = lines.join('\n');
        }
        
        entity.writeAsStringSync(finalContent);
        print('Updated: ${entity.path}');
        count++;
      }
    }
  }
  print('Done. Updated $count files.');
}
