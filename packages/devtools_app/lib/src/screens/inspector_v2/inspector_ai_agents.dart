// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../shared/diagnostics/diagnostics_node.dart';
import '../../shared/diagnostics/primitives/source_location.dart';
import '../../shared/globals.dart';
import '../../shared/managers/error_badge_manager.dart';
import '../../shared/ui/ai_widgets.dart';
import 'inspector_controller.dart';

class FlutterLayoutAgent {
  FlutterLayoutAgent({required this.inspectorController});

  final InspectorController inspectorController;

  late GeminiChatController chatController;

  void init() {
    chatController = GeminiChatController()..init();
  }

  Future<void> fixError({
    required RemoteDiagnosticsNode diagnostic,
    required DevToolsError error,
  }) async {
    // TODO this assumes the row is always selected, it might not be.
    final creationLocation =
        inspectorController.selectedNodeProperties.value.widgetProperties
            .firstWhereOrNull((property) => property.creationLocation != null)
            ?.creationLocation;
    final creationLocationPath = creationLocation?.path!;

    Future<String> buildErrorContext() async {
      int? line;
      int? column;
      String? sourceCode;

      if (creationLocationPath != null) {
        line = creationLocation!.getLine();
        column = creationLocation.getColumn();
        sourceCode =
            (await dtdManager.connection.value?.readFileAsString(
              Uri.parse(creationLocationPath),
            ))?.content;
      }

      return '''
You are a Dart and Flutter expert. You will be given an error message at a
specific line and column in provided Dart source code. You will also be given
additional context about the Widget that the error is associated with. Use this
information to inform the suggested fix.

Please fix the code and return it in it's entirety. The response should be the 
same program as the input with the error fixed.

The response should come back as raw code and not in a Markdown code block.
Make sure to check for layout overflows in the generated code and fix them
before returning the code.

error message: ${error.errorMessage}
error details: ${error.errorDetails ?? {}}
line: $line
column: $column
source code: $sourceCode
widget's diagnostic information: ${diagnostic.json}
widget's name: ${diagnostic.description ?? ''}.
widget's immediate children: ${diagnostic.childrenNow.map((diagnostic) => diagnostic.description).toList()}
widget's parent: ${diagnostic.parent?.description}
''';
    }

    await chatController.sendChat(
      prompt: await buildErrorContext(),
      onChatResponse:
          (response) => _handleChatResponse(response, creationLocation),
    );
  }

  Future<String> stringFromStream(Stream<String> stream) async {
    final buffer = StringBuffer();
    await stream.forEach(buffer.write);
    return buffer.toString();
  }

  Future<void> _handleChatResponse(
    GenerateContentResponse chatResponse,
    InspectorSourceLocation? creationLocation,
  ) async {
    if (chatResponse.text == null) return;

    var cleanResponse = await stringFromStream(
      cleanCode(Stream.value(chatResponse.text!)),
    );
    if (cleanResponse.endsWith(endCodeBlock)) {
      cleanResponse = cleanResponse.substring(
        0,
        cleanResponse.length - endCodeBlock.length,
      );
    }
    const chunkEndWithNewLine = '$endCodeBlock\n';
    if (cleanResponse.endsWith(chunkEndWithNewLine)) {
      cleanResponse = cleanResponse.substring(
        0,
        cleanResponse.length - chunkEndWithNewLine.length,
      );
    }
    final filePath = creationLocation?.path;
    if (filePath != null) {
      await dtdManager.connection.value?.writeFileAsString(
        Uri.parse(filePath),
        cleanResponse,
      );
      await serviceConnection.serviceManager.performHotReload();
    }
  }

  static const startCodeBlock = '```dart\n';
  static const endCodeBlock = '```';
  static Stream<String> cleanCode(Stream<String> stream) async* {
    var foundFirstLine = false;
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      // looking for the start of the code block (if there is one)
      if (!foundFirstLine) {
        buffer.write(chunk);
        if (chunk.contains('\n')) {
          foundFirstLine = true;
          final text = buffer.toString().replaceFirst(startCodeBlock, '');
          buffer.clear();
          if (text.isNotEmpty) yield text;
          continue;
        }

        // still looking for the start of the first line
        continue;
      }

      // looking for the end of the code block (if there is one)
      assert(foundFirstLine);
      String processedChunk;
      if (chunk.endsWith(endCodeBlock)) {
        processedChunk = chunk.substring(0, chunk.length - endCodeBlock.length);
      } else if (chunk.endsWith('$endCodeBlock\n')) {
        processedChunk =
            '${chunk.substring(0, chunk.length - endCodeBlock.length - 1)}\n';
      } else {
        processedChunk = chunk;
      }

      if (processedChunk.isNotEmpty) yield processedChunk;
    }

    // if we're still in the first line, yield it
    if (buffer.isNotEmpty) yield buffer.toString();
  }
}
