import 'dart:io';

void main() {
  final Directory dir = Directory('');
  final List<String> files = <String>[];
  dir.list(recursive: true, followLinks: false).listen(
    (FileSystemEntity entity) {
      String path = entity.path.toString();
      path = path.substring(2);
      files.add(path);
    },
  ).onDone(() {
    print('For Array of assets : ');
    files.forEach((String file) {
      print("\'assets/extra/" + file + "\',");
    });

    print('For Array of pubspec.yaml file : ');
    files.forEach((String file) {
      print('- assets/extra/' + file);
    });
  });
}
