import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as sr;
import 'package:shelf_static/shelf_static.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<void> copyAssetsToDocuments() async {
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final String targetDirPath = path.join(appDocDir.path, 'web');

  // Create the target directory if it doesn't exist
  final Directory targetDir = Directory(targetDirPath);
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  // List of all files to copy
  final List<String> assets = await _getAssetFiles('web');

  for (String asset in assets) {
    final byteData = await rootBundle.load(asset);
    final file =
        File(path.join(targetDirPath, path.relative(asset, from: 'web')));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsBytes(byteData.buffer.asUint8List());
  }
}

Future<List<String>> _getAssetFiles(String assetPath) async {
  final manifestContent = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifestMap = json.decode(manifestContent);
  final assetFiles = manifestMap.keys
      .where((String key) => key.startsWith(assetPath))
      .toList();
  return assetFiles;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await copyAssetsToDocuments();
  runApp(MyApp());
  startServer();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Server Example'),
        ),
        body: Center(
          child: Text('Server is running...'),
        ),
      ),
    );
  }
}

void startServer() async {
  final router = sr.Router();

  // Get the correct path to the directory containing the web files
  Directory appDocDir = await getApplicationDocumentsDirectory();
  String webDirPath = path.join(appDocDir.path, 'web');

  // Ensure this directory exists and contains the necessary files
  final staticHandler = createStaticHandler(
    webDirPath,
    defaultDocument: 'index.html',
  );

  router.get('/<ignored|.*>', staticHandler);

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router);

  const port = 8084;
  final server = await shelf_io.serve(handler, '0.0.0.0', port);

  print('Server running on ${server.address}:$port');

  /// run with http://0.0.0.0:8084/index.html
}
