import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/message.dart';
import 'package:nexon/providers/chat_provider.dart';

class ChatInput extends ConsumerStatefulWidget {
  final Function(String) onSendMessage;
  final bool isGenerating;
  final VoidCallback onStop;
  final Message? editingMessage;

  const ChatInput({Key? key, required this.onSendMessage, required this.isGenerating, required this.onStop, this.editingMessage}) : super(key: key);

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _textController = TextEditingController();
  late final FocusNode _focusNode;
  bool _isComposing = false;
  Message? _previousEditingMessage;

  @override
  void initState() {
    super.initState();
    // Initialize focus node with key event handler
    _focusNode = FocusNode(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

          if (!isShiftPressed && _isComposing && !widget.isGenerating) {
            _handleSubmitted();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _textController.addListener(_handleTextChanged);
    _updateTextIfEditing();
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTextIfEditing();
  }

  void _updateTextIfEditing() {
    if (widget.editingMessage != null && widget.editingMessage != _previousEditingMessage) {
      _previousEditingMessage = widget.editingMessage;
      // Get text from the message being edited
      if (widget.editingMessage!.blocks.isNotEmpty && widget.editingMessage!.blocks.first is TextBlock) {
        final text = (widget.editingMessage!.blocks.first as TextBlock).text;
        _textController.text = text;
        _focusNode.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {
      _isComposing = _textController.text.isNotEmpty;
    });
  }

  void _handleSubmitted() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.editingMessage != null;

    return Column(
      children: [
        // Show edit banner if editing
        if (isEditing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: colorScheme.primaryContainer.withOpacity(0.5),
            child: Row(
              children: [
                Icon(Icons.edit_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Editing message', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500))),
                InkWell(
                  onTap: () {
                    ref.read(chatMessagesProvider.notifier).cancelEditing();
                    _textController.clear();
                  },
                  child: Padding(padding: const EdgeInsets.all(4.0), child: Icon(Icons.close_rounded, size: 18, color: colorScheme.primary)),
                ),
              ],
            ),
          ),

        // Normal input area
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Main text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isGenerating ? colorScheme.surfaceVariant.withOpacity(0.4) : colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color:
                          isEditing
                              ? colorScheme.primary
                              : widget.isGenerating
                              ? colorScheme.outline.withOpacity(0.3)
                              : colorScheme.primary.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [BoxShadow(color: colorScheme.shadow.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !widget.isGenerating,
                    style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: widget.isGenerating ? 'Generating response...' : 'Type a message...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      suffixIcon:
                          _isComposing
                              ? IconButton(
                                icon: Icon(Icons.clear_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                onPressed: () {
                                  _textController.clear();
                                },
                              )
                              : null,
                    ),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    onSubmitted: null, // Disable default submission
                    onTapOutside: (_) => _focusNode.unfocus(),
                    cursorColor: colorScheme.primary,
                    cursorWidth: 2,
                    cursorRadius: const Radius.circular(2),
                  ),
                ),
              ),

              // Send or Stop button
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Material(
                  color:
                      widget.isGenerating
                          ? colorScheme.errorContainer
                          : _isComposing
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceVariant.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                  elevation: widget.isGenerating ? 2 : 0, // Add elevation to stop button for emphasis
                  child: InkWell(
                    onTap:
                        widget.isGenerating
                            ? widget.onStop
                            : _isComposing
                            ? _handleSubmitted
                            : null,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 48,
                      width: 48,
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child:
                            widget.isGenerating
                                ? Icon(Icons.stop_rounded, color: colorScheme.onErrorContainer, size: 24, key: const ValueKey('stop'))
                                : Icon(
                                  Icons.send_rounded,
                                  color: _isComposing ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant.withOpacity(0.4),
                                  size: 22,
                                  key: const ValueKey('send'),
                                ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
