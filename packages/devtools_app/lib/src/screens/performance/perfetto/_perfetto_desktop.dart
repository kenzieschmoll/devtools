import 'package:flutter/material.dart';

void registerWebView() {}

class Perfetto extends StatelessWidget {
  const Perfetto({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('IFrames are not supported on desktop platforms.'),
    );
  }
}
