import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

class Perfetto extends StatefulWidget {
  const Perfetto({Key? key}) : super(key: key);

  @override
  State<Perfetto> createState() => _PerfettoState();
}

class _PerfettoState extends State<Perfetto> {
  // static const perfettoUrl = 'https://ui.perfetto.dev';

  /// Url when running Perfetto locally following the instructions here:
  /// https://perfetto.dev/docs/contributing/build-instructions#ui-development
  static const _perfettoUrl = 'http://127.0.0.1:10000';

  late final Completer<void> _perfettoReady;

  late final html.IFrameElement _perfettoIFrame;

  @override
  void initState() {
    super.initState();
    _perfettoReady = Completer();
    _perfettoIFrame = html.IFrameElement()
      ..height = '100%'
      ..width = '100%'
      ..src = _perfettoUrl
      ..style.border = 'none';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'embedded-perfetto',
      (int viewId) => _perfettoIFrame,
    );

    html.window.addEventListener('message', _handleMessage);
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(denseSpacing),
            height: defaultButtonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text('WIP test controls:'),
                ElevatedButton(
                  onPressed: _pingUntilReady,
                  child: const Text('Ping'),
                ),
                ElevatedButton(
                  onPressed: _loadTrace,
                  child: const Text('Load Trace'),
                ),
              ],
            ),
          ),
          Expanded(
            child: HtmlElementView(
              key: UniqueKey(),
              viewType: 'embedded-perfetto',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTrace() async {
    await _pingUntilReady();

    const testUrl =
        'https://storage.googleapis.com/perfetto-misc/example_android_trace_15s';
    final request = html.HttpRequest()
      ..open('GET', testUrl, async: true)
      ..responseType = 'arraybuffer';
    request.send();
    await request.onLoad.first;
    final arrayBuffer = (request.response as ByteBuffer).asUint8List();

    _postMessage({
      'perfetto': {
        'buffer': arrayBuffer,
        'title': 'My Loaded Trace',
        'url': '$_perfettoUrl#reopen=$testUrl',
      }
    });
  }

  Future<void> _pingUntilReady() async {
    if (!_perfettoReady.isCompleted) {
      while (!_perfettoReady.isCompleted) {
        await Future.delayed(const Duration(microseconds: 100), () async {
          // Once the Perfetto UI is ready, Perfetto will receive this 'PING'
          // message and return a 'PONG' message, handled in [_handleMessage]
          // below.
          _postMessage('PING');
        });
      }
    }
  }

  void _postMessage(dynamic message) {
    _perfettoIFrame.contentWindow!.postMessage(message, _perfettoUrl);
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      if (e.data == 'PONG' && !_perfettoReady.isCompleted) {
        _perfettoReady.complete();
      }
    }
  }
}
