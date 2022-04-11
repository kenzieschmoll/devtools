import 'dart:async';

import 'package:flutter/material.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

void registerWebView() {
  WebView.platform = WebWebViewPlatform();
}

class Perfetto extends StatefulWidget {
  const Perfetto({Key? key}) : super(key: key);

  @override
  State<Perfetto> createState() => _PerfettoState();
}

class _PerfettoState extends State<Perfetto> {
  static const _perfettoUrl = 'https://ui.perfetto.dev/';

  late final Completer<WebViewController> _controllerCompleter;

  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controllerCompleter = Completer<WebViewController>();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 40.0,
            child: ElevatedButton(
              child: Text('post'),
              onPressed: _postMessage,
            ),
          ),
          Expanded(
            child: WebView(
              initialUrl: _perfettoUrl,
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController controller) {
                _controllerCompleter.complete(controller);
                _controller = controller;
              },
            ),
          ),
        ],
      ),
    );
  }

  void _postMessage() {
    _controller.runJavascriptReturningResult(
        'window.postMessage(\'PING\', \'https://ui.perfetto.dev/\')');
  }
}
