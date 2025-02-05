// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiChatController {

  late final GenerativeModel _model;
  late final ChatSession _chat;

  void init() {
    _model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: _apiKey);
    _chat = _model.startChat();
  }

  Future<void> sendChat({
    required String prompt,
    String? promptContext,
    FutureOr<void> Function(GenerateContentResponse chatResponse)?
    onChatResponse,
    bool newChat = false,
  }) async {
    if (newChat) {
      // TODO(kenz): does this leak or does the previous chat session get GC'ed
      // automatically.
      _chat = _model.startChat();
    }
    final response = await _chat.sendMessage(
      Content.text([promptContext, prompt].nonNulls.join('\n')),
    );
    await onChatResponse?.call(response);
  }
}

// class GeminiChatWidgetController {
//   Stream<String> get _chats => _chatController.stream;

//   final _chatController = StreamController<String>.broadcast();

//   void chat(String message) {
//     _chatController.add(message);
//   }

//   Future<void> dispose() async {
//     await _chatController.close();
//   }
// }

class GeminiChatWidget extends StatefulWidget {
  const GeminiChatWidget({
    super.key,

    required this.prompt,
    required this.hintText,
    // this.chatController,
    this.onChatResponse,
  });

  final String prompt;
  final String hintText;
  // final GeminiChatWidgetController? chatController;
  final FutureOr<void> Function(String chatResponse)? onChatResponse;

  @override
  State<GeminiChatWidget> createState() => _GeminiChatWidgetState();
}

class _GeminiChatWidgetState extends State<GeminiChatWidget>
    with AutoDisposeMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = false;

  late GeminiChatController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = GeminiChatController()..init();
    // _listenForIncomingChats();
  }

  @override
  void dispose() {
    // _chatController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GeminiChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (widget.chatController != oldWidget.chatController) {
    //   cancelListeners();
    //   _listenForIncomingChats();
    // }
  }

  // void _listenForIncomingChats() {
  //   if (widget.chatController != null) {
  //     autoDisposeStreamSubscription(
  //       widget.chatController!._chats.listen((message) async {
  //         await _sendAndHandleChat(message);
  //       }),
  //     );
  //   }
  // }

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
    final history = _chatController._chat.history.toList();
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
                return _MessageWidget(
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
                    decoration: textFieldDecoration(context, widget.hintText),
                    controller: _textController,
                    onSubmitted: _sendChatMessage,
                  ),
                ),
                const SizedBox.square(dimension: 15),
                if (!_loading)
                  IconButton(
                    onPressed: () async {
                      await _sendChatMessage(_textController.text);
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

  Future<void> _sendChatMessage(String message) async {
    setState(() {
      _loading = true;
    });

    try {
      await _chatController.sendChat(
        promptContext: widget.prompt,
        prompt: message,
        onChatResponse: (response) {
          final text = response.text;
          if (text == null) {
            _showError('Empty response.');
          } else {
            setState(() {
              _loading = false;
              _scrollDown();
            });
          }
        },
      );
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
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

class _MessageWidget extends StatelessWidget {
  const _MessageWidget({required this.text, required this.isFromUser});

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
