import 'dart:convert';
import 'dart:io';

/// Script to:
/// 1. Add slug columns to courses, lessons, and categories tables
/// 2. Backfill existing rows with auto-generated slugs from their titles/names
void main() async {
  final url = Uri.parse(
      'https://api.supabase.com/v1/projects/cstlqyjoflhxtocrtypg/query');
  final headers = {
    'Authorization': 'Bearer sbp_3051a71089ed73fc406a6c888f08685e1ab9fbc5',
    'Content-Type': 'application/json',
  };

  // Step 1: Add columns (idempotent)
  final addColumnsQuery = jsonEncode({
    'query': '''
      ALTER TABLE courses ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE;
      ALTER TABLE lessons ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE;
      ALTER TABLE categories ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE;
    '''
  });

  // Step 2: Backfill slugs for existing courses (using title → slugified)
  final backfillCoursesQuery = jsonEncode({
    'query': '''
      UPDATE courses
      SET slug = LOWER(REGEXP_REPLACE(TRIM(title), '[^a-zA-Z0-9]+', '-', 'g'))
      WHERE slug IS NULL OR slug = '';
    '''
  });

  // Step 3: Backfill slugs for existing lessons
  final backfillLessonsQuery = jsonEncode({
    'query': '''
      UPDATE lessons
      SET slug = LOWER(REGEXP_REPLACE(TRIM(title), '[^a-zA-Z0-9]+', '-', 'g'))
      WHERE slug IS NULL OR slug = '';
    '''
  });

  // Step 4: Backfill slugs for existing categories
  final backfillCategoriesQuery = jsonEncode({
    'query': '''
      UPDATE categories
      SET slug = LOWER(REGEXP_REPLACE(TRIM(name), '[^a-zA-Z0-9]+', '-', 'g'))
      WHERE slug IS NULL OR slug = '';
    '''
  });

  await runQuery('Adding slug columns...', url, headers, addColumnsQuery);
  await runQuery('Backfilling course slugs...', url, headers, backfillCoursesQuery);
  await runQuery('Backfilling lesson slugs...', url, headers, backfillLessonsQuery);
  await runQuery('Backfilling category slugs...', url, headers, backfillCategoriesQuery);

  stdout.writeln('\n✅ Done! All slugs have been created.');
}

Future<void> runQuery(String label, Uri url, Map<String, String> headers, String body) async {
  stdout.writeln('\n⏳ $label');
  try {
    final client = HttpClient();
    final request = await client.postUrl(url);
    headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    request.write(body);
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode == 200 || response.statusCode == 201) {
      stdout.writeln('  ✅ Success');
    } else {
      stderr.writeln('  ❌ Error ${response.statusCode}: $responseText');
    }
    client.close();
  } catch (e) {
    stderr.writeln('  ❌ Exception: $e');
  }
}
