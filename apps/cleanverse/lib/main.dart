// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/app.dart';
import 'package:cleanverse/src/features/example/demo_scan.dart';

void main() => runApp(CleanVerseApp(repository: DemoScanRepository()));
