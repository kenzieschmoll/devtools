// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/ai_widgets.dart';
import 'property_editor_controller.dart';

class AiPropertyEditor extends StatelessWidget {
  const AiPropertyEditor({super.key, required this.propertyEditorController});

  final PropertyEditorController propertyEditorController;

  @override
  Widget build(BuildContext context) {
    final prompt = '''
You are a Dart and Flutter expert. You will be given a list of arguments for a
Widget that are editable. You will be given a request to modify this Widget in
some way. You should suggest an edit to one of the editable arguments to
perform the requested modification. Return the suggested edit as a JSON response.

In the JSON response, please include the raw JSON for the argument you have
chosen to edit. You should pull this value directly from the list of arguments
you will be given below. This value should be identical to exactly one of the
arguments in the list you will be given below.

{
  "argument": <raw JSON for selected argument>
}

In the JSON response, please include the new value you are suggesting that this
argument be edited to have.

{
  "value": <edit value as a string>
}

Please write the edit value as if you had to write it in Dart code that
compiles. You should use the latest Flutter SDK APIs to ensure you are
suggesting valid Dart code.

In total, your JSON response should have two fields: "argument" and "value".

Here is the list of editable arguments:

${propertyEditorController.editableArgs.value.map((arg) => arg.toJson()).toList()}

Here is the edit request:

''';
    return GeminiChatWidget(
      prompt: prompt,
      hintText: 'How do you want to edit this Widget?',
      onChatResponse: _attemptEdit,
    );
  }

  Future<void> _attemptEdit(String chatResponse) async {
    try {
      final decoded = jsonDecode(chatResponse) as Map<String, Object?>;
      final argument = decoded['argument'] as Map<String, Object?>;
      final argumentName = argument['name'] as String;
      final argumentType = argument['type'];
      final newValue = decoded['value'];

      final matchingArgument = propertyEditorController.editableArgs.value
          .firstWhereOrNull((arg) => arg.name == argumentName);
      if (matchingArgument == null) {
        print('Could not find editable argument named $argumentName.');
        return;
      }

      if (argumentType == 'enum') {
        final options = argument['options'] as List;
        if (!options.contains(newValue)) {
          print(
            'The suggested edit $newValue is not a valid edit for the '
            '$argumentName property.',
          );
          return;
        }
        await propertyEditorController.editArgument(
          name: argumentName,
          value: newValue,
        );
      } else if (argumentType == 'double') {
        final double? typedValue =
            newValue.runtimeType == double
                ? newValue as double
                : double.tryParse(newValue as String);
        if (typedValue == null) {
          print('Could not parse $newValue as a double.');
          return;
        }
        await propertyEditorController.editArgument(
          name: argumentName,
          value: typedValue,
        );
      } else if (argumentType == 'int') {
        final int? typedValue =
            newValue.runtimeType == int
                ? newValue as int
                : int.tryParse(newValue as String);
        if (typedValue == null) {
          print('Could not parse $newValue as an int.');
          return;
        }
        await propertyEditorController.editArgument(
          name: argumentName,
          value: typedValue,
        );
      } else {
        await propertyEditorController.editArgument(
          name: argumentName,
          value: newValue,
        );
      }
    } catch (e) {
      print('Could not parse AI response: $e');
    }
  }
}
