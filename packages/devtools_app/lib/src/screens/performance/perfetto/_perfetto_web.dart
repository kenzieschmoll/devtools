// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

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
      child: const HtmlElementView(
        viewType: PerfettoController.viewId,
      ),
    );
  }
}
