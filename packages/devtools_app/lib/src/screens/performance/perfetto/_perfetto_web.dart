// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  PerfettoController get perfettoController =>
      widget.performanceController.perfettoController as PerfettoController;

  @override
  bool wantKeepAlive = true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                  onPressed: perfettoController.pingUntilReady,
                  child: const Text('Ping'),
                ),
                ElevatedButton(
                  onPressed: perfettoController.loadTrace,
                  child: const Text('Load Trace'),
                ),
              ],
            ),
          ),
          const Expanded(
            child: HtmlElementView(
              viewType: PerfettoController.viewId,
            ),
          ),
        ],
      ),
    );
  }
}
