// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../performance_controller.dart';
import '_perfetto_controller_web.dart';

class Perfetto extends StatefulWidget {
  const Perfetto({
    Key? key,
    required this.performanceController,
  }) : super(key: key);

  final PerformanceController performanceController;

  @override
  State<Perfetto> createState() => _PerfettoState();
}

class _PerfettoState extends State<Perfetto>
    with AutomaticKeepAliveClientMixin {
  late final Completer<void> _perfettoReady;

  PerfettoController get perfettoController =>
      widget.performanceController.perfettoController as PerfettoController;

  @override
  bool wantKeepAlive = true;

  @override
  void initState() {
    super.initState();
    _perfettoReady = Completer();
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
          const Expanded(
            child: HtmlElementView(
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
        'url': '${perfettoController.perfettoUrl}#reopen=$testUrl',
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
    perfettoController.perfettoIFrame.contentWindow!.postMessage(
      message,
      perfettoController.perfettoUrl,
    );
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      if (e.data == 'PONG' && !_perfettoReady.isCompleted) {
        _perfettoReady.complete();
      }
    }
  }
}
