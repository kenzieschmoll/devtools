// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'performance_controller.dart';
import 'performance_model.dart';

String computeEventGroupKey(
  TimelineEvent event,
  Map<int, String> threadNamesById,
) {
  if (event.groupKey != null) {
    return event.groupKey;
  } else if (event.isAsyncEvent) {
    return event.root.name;
  } else if (event.isUiEvent) {
    return TimelineController.uiKey;
  } else if (event.isRasterEvent) {
<<<<<<< Updated upstream
    return PerformanceData.rasterKey;
=======
    return TimelineController.rasterKey;
>>>>>>> Stashed changes
  } else if (threadNamesById[event.threadId] != null) {
    return threadNamesById[event.threadId];
  } else {
    return TimelineController.unknownKey;
  }
}
