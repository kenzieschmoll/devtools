// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'property_editor_controller.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key, required this.propertyEditorController});

  final PropertyEditorController propertyEditorController;

  static const apiKey = 'bring-your-own-key';

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-pro', apiKey: ChatWidget.apiKey);
    _chat = _model.startChat();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async => await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _chat.history.toList();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemBuilder: (context, idx) {
                final content = history[idx];
                final text =
                    content.parts
                        .whereType<TextPart>()
                        .map<String>((e) => e.text)
                        .join();
                return MessageWidget(
                  text: text,
                  isFromUser: content.role == 'user',
                );
              },
              itemCount: history.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    focusNode: _textFieldFocus,
                    decoration: textFieldDecoration(
                      context,
                      'How do you want to edit this Widget?',
                    ),
                    controller: _textController,
                    onSubmitted: (String value) async {
                      final response = await _sendChatMessage(value);
                      await _attemptEdit(response);
                    },
                  ),
                ),
                const SizedBox.square(dimension: 15),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      final response = await _sendChatMessage(
                        _textController.text,
                      );
                      await _attemptEdit(response);
                    },
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _attemptEdit(String chatResponse) async {
    try {
      final decoded = jsonDecode(chatResponse) as Map<String, Object?>;
      final argument = decoded['argument'] as Map<String, Object?>;
      final argumentName = argument['name'] as String;
      final argumentType = argument['type'];
      final newValue = decoded['value'];

      final matchingArgument = widget
          .propertyEditorController
          .editableArgs
          .value
          .firstWhereOrNull((arg) => arg.name == argumentName);
      if (matchingArgument == null) {
        _showError('Could not find editable argument named $argumentName.');
        return;
      }

      if (argumentType == 'enum') {
        final options = argument['options'] as List;
        if (!options.contains(newValue)) {
          _showError(
            'The suggested edit $newValue is not a valid edit for the '
            '$argumentName property.',
          );
          return;
        }
        await widget.propertyEditorController.editArgument(
          name: argumentName,
          value: newValue,
        );
      } else if (argumentType == 'double') {
        final double? typedValue =
            newValue.runtimeType == double
                ? newValue as double
                : double.tryParse(newValue as String);
        if (typedValue == null) {
          _showError('Could not parse $newValue as a double.');
          return;
        }
        await widget.propertyEditorController.editArgument(
          name: argumentName,
          value: typedValue,
        );
      } else if (argumentType == 'int') {
        final int? typedValue =
            newValue.runtimeType == int
                ? newValue as int
                : int.tryParse(newValue as String);
        if (typedValue == null) {
          _showError('Could not parse $newValue as an int.');
          return;
        }
        await widget.propertyEditorController.editArgument(
          name: argumentName,
          value: typedValue,
        );
      } else {
        await widget.propertyEditorController.editArgument(
          name: argumentName,
          value: newValue,
        );
      }
    } catch (e) {
      _showError('Could not parse AI response: $e');
    }
  }

  Future<String> _sendChatMessage(String message) async {
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

${widget.propertyEditorController.editableArgs.value.map((arg) => arg.toJson()).toList()}

Here is the edit request:

''';
    setState(() {
      _loading = true;
    });

    try {
      final response = await _chat.sendMessage(Content.text('$prompt$message'));
      final text = response.text;

      if (text == null) {
        _showError('Empty response.');
        return '';
      } else {
        setState(() {
          _loading = false;
          _scrollDown();
        });
      }

      return text;
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
      return '';
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  void _showError(String message) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Something went wrong'),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  final String text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color:
                  isFromUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 8),
            child: MarkdownBody(data: text),
          ),
        ),
      ],
    );
  }
}

InputDecoration textFieldDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
    );
