import 'dart:io';

void main() {
  final recetasDir = Directory('Recetas');
  var totalFixed = 0;

  for (final regionDir in recetasDir.listSync().whereType<Directory>()) {
    for (final file in regionDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      var content = file.readAsStringSync();
      final original = content;

      content = content.replaceAllMapped(
        RegExp(r'"porciones":\s*"?(\d+)\s+[a-zA-Z]+"?'),
        (match) => '"porciones": ${match.group(1)!}',
      );

      if (content != original) {
        file.writeAsStringSync(content);
        final fixed = RegExp(r'"porciones":\s*"?(\d+)\s+[a-zA-Z]+"?').allMatches(original).length;
        totalFixed += fixed;
        print('✅ ${file.path.split(Platform.pathSeparator).last}: $fixed correcciones');
      }
    }
  }
  print('\n🔧 Total de valores corregidos: $totalFixed');
}
