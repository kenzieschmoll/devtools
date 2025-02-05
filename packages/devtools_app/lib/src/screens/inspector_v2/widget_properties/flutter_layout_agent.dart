// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// import 'dart:async';

// import 'package:collection/collection.dart';
// import 'package:devtools_app_shared/ui.dart';
// import 'package:flutter/material.dart';

// import '../../../shared/console/eval/inspector_tree_v2.dart';
// import '../../../shared/diagnostics/diagnostics_node.dart';
// import '../../../shared/diagnostics/primitives/source_location.dart';
// import '../../../shared/framework/screen.dart';
// import '../../../shared/globals.dart';
// import '../../../shared/managers/error_badge_manager.dart';
// import '../../../shared/ui/ai_widgets.dart';
// import '../../../shared/ui/common_widgets.dart';
// import '../inspector_controller.dart';

// class FlutterLayoutAgent extends StatefulWidget {
//   const FlutterLayoutAgent({
//     super.key,
//     required this.inspectorController,
//     required this.widgetProperties,
//   });

//   final InspectorController inspectorController;
//   final List<RemoteDiagnosticsNode> widgetProperties;

//   @override
//   State<FlutterLayoutAgent> createState() => _FlutterLayoutAgentState();
// }

// class _FlutterLayoutAgentState extends State<FlutterLayoutAgent> {
//   late GeminiChatWidgetController chatController;

//   InspectorTreeNode? get selectedNode =>
//       widget.inspectorController.selectedNode.value;

//   RemoteDiagnosticsNode? get selectedDiagnostic => selectedNode?.diagnostic;

//   @override
//   void initState() {
//     super.initState();
//     chatController = GeminiChatWidgetController();
//   }

//   @override
//   void dispose() {
//     unawaited(chatController.dispose());
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (selectedDiagnostic == null) {
//       return const CenteredMessage(
//         message: 'Select a Widget to use AI assistance.',
//       );
//     }
//     final error = errorForSelectedDiagnostic();
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(defaultSpacing),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               // DevToolsButton(
//               //   label: 'Explain this Widget',
//               //   icon: Icons.info_outlined,
//               //   elevated: true,
//               //   onPressed: () async {
//               //     chatController.chat(
//               //       await _buildChatMessage('Explain this Widget'),
//               //     );
//               //   },
//               // ),
//               if (error != null)
//                 DevToolsButton(
//                   label: 'Fix this error',
//                   icon: Icons.auto_awesome,
//                   elevated: true,
//                   onPressed: () async {
//                     chatController.chat(await _buildErrorContext(error));
//                   },
//                 ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: GeminiChatWidget(
//             hintText: 'Ask a question about this Widget',
//             prompt: '',
//             chatController: chatController,
//             onChatResponse: _handleChatResponse,
//           ),
//         ),
//       ],
//     );
//   }

//   InspectorSourceLocation? creationLocationForSelectedDiagnostic() {
//     return widget.widgetProperties
//         .firstWhereOrNull((property) => property.creationLocation != null)
//         ?.creationLocation;
//   }

//   DevToolsError? errorForSelectedDiagnostic() {
//     // Check whether the selected node has any errors associated with it.
//     final inspectorRef = selectedDiagnostic?.valueRef.id;
//     final errors =
//         serviceConnection.errorBadgeManager
//             .erroredItemsForPage(ScreenMetaData.inspector.id)
//             .value;
//     final error = errors[inspectorRef];
//     return error;
//   }

//   Future<String> _buildErrorContext(DevToolsError error) async {
//     final creationLocation = creationLocationForSelectedDiagnostic();
//     final creationLocationPath = creationLocation?.path!;

//     int? line;
//     int? column;
//     String? sourceCode;

//     if (creationLocationPath != null) {
//       line = creationLocation!.getLine();
//       column = creationLocation.getColumn();
//       sourceCode =
//           (await dtdManager.connection.value?.readFileAsString(
//             Uri.parse(creationLocationPath),
//           ))?.content;
//     }

//     return '''
// You are a Dart and Flutter expert. You will be given an error message at a
// specific line and column in provided Dart source code. You will also be given
// additional context about the Widget that the error is associated with. Use this
// information to inform the suggested fix.

// Please fix the code and return it in it's entirety. The response should be the 
// same program as the input with the error fixed.

// The response should come back as raw code and not in a Markdown code block.
// Make sure to check for layout overflows in the generated code and fix them
// before returning the code.

// error message: ${error.errorMessage}
// error details: ${error.errorDetails ?? {}}
// line: $line
// column: $column
// source code: $sourceCode
// widget's diagnostic information: ${selectedDiagnostic!.json}
// widget's name: ${selectedDiagnostic!.description ?? ''}.
// widget's immediate children: ${selectedDiagnostic!.childrenNow.map((diagnostic) => diagnostic.description).toList()}
// widget's parent: ${selectedDiagnostic!.parent?.description}
// ''';
//   }

  // Future<String> stringFromStream(Stream<String> stream) async {
  //   final buffer = StringBuffer();
  //   await stream.forEach(buffer.write);
  //   return buffer.toString();
  // }

  // Future<void> _handleChatResponse(String chatResponse) async {
  //   var cleanResponse = await stringFromStream(
  //     cleanCode(Stream.value(chatResponse)),
  //   );
  //   const chunkEnd = '$endCodeBlock\n';
  //   if (cleanResponse.endsWith(chunkEnd)) {
  //     cleanResponse = cleanResponse.substring(0, cleanResponse.length - chunkEnd.length);
  //   }
  //   final filePath = creationLocationForSelectedDiagnostic()?.path;
  //   if (filePath != null) {
  //     await dtdManager.connection.value?.writeFileAsString(
  //       Uri.parse(filePath),
  //       cleanResponse,
  //     );
  //   }
  // }

  // static const startCodeBlock = '```dart\n';
  // static const endCodeBlock = '```';
  // static Stream<String> cleanCode(Stream<String> stream) async* {
  //   var foundFirstLine = false;
  //   final buffer = StringBuffer();
  //   await for (final chunk in stream) {
  //     // looking for the start of the code block (if there is one)
  //     if (!foundFirstLine) {
  //       buffer.write(chunk);
  //       if (chunk.contains('\n')) {
  //         foundFirstLine = true;
  //         final text = buffer.toString().replaceFirst(startCodeBlock, '');
  //         buffer.clear();
  //         if (text.isNotEmpty) yield text;
  //         continue;
  //       }

  //       // still looking for the start of the first line
  //       continue;
  //     }

  //     // looking for the end of the code block (if there is one)
  //     assert(foundFirstLine);
  //     String processedChunk;
  //     if (chunk.endsWith(endCodeBlock)) {
  //       processedChunk = chunk.substring(0, chunk.length - endCodeBlock.length);
  //     } else if (chunk.endsWith('$endCodeBlock\n')) {
  //       processedChunk =
  //           '${chunk.substring(0, chunk.length - endCodeBlock.length - 1)}\n';
  //     } else {
  //       processedChunk = chunk;
  //     }

  //     if (processedChunk.isNotEmpty) yield processedChunk;
  //   }

  //   // if we're still in the first line, yield it
  //   if (buffer.isNotEmpty) yield buffer.toString();
  // }

//   //   Future<String> _buildChatMessage(String message) async {
//   //     return '$message\n${await _buildContext()}';
//   //   }

//   //   Future<String> _buildContext() async {
//   //     final creationLocation =
//   //         widget.widgetProperties
//   //             .firstWhereOrNull((property) => property.creationLocation != null)
//   //             ?.creationLocation;
//   //     String? creationLocationDescription;
//   //     String? creationLibraryContent;
//   //     final creationLocationPath = creationLocation?.path!;
//   //     if (creationLocationPath != null) {
//   //       creationLocationDescription =
//   //           'The location in the Flutter project where the Widget was created is '
//   //           '$creationLocationPath at line: ${creationLocation!.getLine()}, '
//   //           'column: ${creationLocation.getColumn()}';
//   //       final fileContent =
//   //           (await dtdManager.connection.value?.readFileAsString(
//   //             Uri.parse(creationLocationPath),
//   //           ))?.content;
//   //       creationLibraryContent =
//   //           fileContent != null
//   //               ? 'The content for the library where this widget was created is here:\n $fileContent'
//   //               : '';
//   //     }

//   //     return '''
//   // You are an expert Dart and Flutter developer. You should use the latest Flutter
//   // SDK APIs to ensure you are suggesting valid Dart code.

//   // I am going to give you context about a Flutter widget from the widget tree of
//   // a running Flutter app. Based on that context, please perform the request that
//   // is at the end of this message.

//   // Here is context about the Widget:

//   // The raw JSON of the widget's diagnostic information is here:
//   // ${selectedDiagnostic!.json}

//   // The widget's name is: ${selectedDiagnostic!.description ?? ''}.

//   // The widget's immediate children are: ${selectedDiagnostic!.childrenNow.map((diagnostic) => diagnostic.description).toList()}

//   // The widget's parent is: ${selectedDiagnostic!.parent?.description}

//   // ${creationLibraryContent ?? ''}

//   // ${creationLocationDescription ?? ''}

//   // The properties for the Widget are: ${widget.widgetProperties.map((node) => node.json).toList()}

//   // ''';
//   //   }
// }
