// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '_perfetto_controller_web.dart';

class Perfetto extends StatefulWidget {
  const Perfetto({
    Key? key,
    required this.perfettoController,
  }) : super(key: key);

  final PerfettoController perfettoController;

  @override
  State<Perfetto> createState() => _PerfettoState();
}

class _PerfettoState extends State<Perfetto> {
  static final overlayExpression = RegExp(r'OverlayEntry#');

  late Timer timer;

  int? startingOverlayCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TODO(kenz): we should be able to remove this workaround and use a
    // [PointerInterceptor] widget once
    // https://github.com/flutter/flutter/issues/105485 is fixed.
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final currentOverlay = Overlay.of(context);
      if (currentOverlay != null) {
        final overlayEntryCount = _countOverlays(currentOverlay);
        final startingCountLocal = startingOverlayCount;
        if (startingCountLocal == null) {
          startingOverlayCount = overlayEntryCount;
        } else {
          if (overlayEntryCount == startingCountLocal) {
            widget.perfettoController.togglePointerEvents(true);
          }
          if (overlayEntryCount > startingCountLocal) {
            widget.perfettoController.togglePointerEvents(false);
          }
        }
      } else {
        // Do nothing. There should be a couple overlays in
        // [Overlay.of(context)] by default.
      }
    });
  }

  int _countOverlays(OverlayState overlay) {
    final overlayStateDescription = overlay.toString();
    return overlayExpression.allMatches(overlayStateDescription).length;
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const HtmlElementView(
        viewType: PerfettoController.viewId,
      ),
    );
  }
}
