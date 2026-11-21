// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/demo_scan.dart';

void main() => runApp(CleanVerseApp(repository: DemoScanRepository()));
