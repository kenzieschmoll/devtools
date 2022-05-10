import 'package:flutter/material.dart';

import '_perfetto_desktop.dart' if (dart.library.html) '_perfetto_web.dart';

class EmbeddedPerfetto extends StatelessWidget {
  const EmbeddedPerfetto({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Perfetto();
  }
}
