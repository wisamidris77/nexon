import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nexon/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onEdit;
  final bool isGenerating;

  const MessageBubble({Key? key, required this.message, this.onEdit, this.isGenerating = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == Role.user;
    final colorScheme = Theme.of(context).colorScheme;

    // Define bubble colors based on message sender and theme
    final bubbleColor = isUser ? colorScheme.primary.withOpacity(0.9) : colorScheme.surfaceVariant;

    final textColor = isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Avatar for bot messages
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: colorScheme.primary.withOpacity(0.15),
                      child: Icon(Icons.smart_toy_rounded, color: colorScheme.primary, size: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Assistant',
                      style: TextStyle(fontSize: 12, color: colorScheme.onBackground.withOpacity(0.7), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

            Container(
              margin: EdgeInsets.only(left: isUser ? 48.0 : 0, right: isUser ? 0 : 48.0),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              child: Material(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final block in message.blocks) _buildBlock(context, block, textColor),

                      // Show typing indicator if the message is generating
                      if (isGenerating && message.blocks.isNotEmpty && message.blocks.first is TextBlock) _buildTypingIndicator(context, textColor),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            if (isUser && onEdit != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.blocks.isNotEmpty && message.blocks.first is TextBlock)
                      InkWell(
                        onTap: () {
                          final text = (message.blocks.first as TextBlock).text;
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Message copied to clipboard'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              width: 220,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 14, color: colorScheme.onBackground.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text('Copy', style: TextStyle(fontSize: 12, color: colorScheme.onBackground.withOpacity(0.6))),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 14, color: colorScheme.onBackground.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text('Edit', style: TextStyle(fontSize: 12, color: colorScheme.onBackground.withOpacity(0.6))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context, Color textColor) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 16,
          width: 2,
          decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(8)),
          child: _BlinkingCursor(color: textColor),
        ),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, MessageBlock block, Color textColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.role == Role.user;

    if (block is TextBlock) {
      final textContent = block.text;

      // Check if content has markdown syntax
      final bool hasMarkdown =
          textContent.contains('```') ||
          textContent.contains('#') ||
          textContent.contains('**') ||
          textContent.contains('*') ||
          textContent.contains('- ') ||
          textContent.contains('1. ') ||
          textContent.contains('[') ||
          textContent.contains('![') ||
          textContent.contains('|');

      // Use SelectableText for plain text or if Markdown might cause issues
      if (!hasMarkdown) {
        return SelectableText(textContent, style: TextStyle(color: textColor, fontSize: 15, height: 1.4));
      }

      // Use Markdown for formatted text
      try {
        return MarkdownBody(
          data: textContent,
          selectable: true,
          onTapLink: (text, url, title) {
            // Handle link taps safely
            if (url != null) {
              // Could implement URL opening here
            }
          },
          styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 15, height: 1.4),
            code: TextStyle(
              backgroundColor: isUser ? colorScheme.primary.withOpacity(0.2) : colorScheme.surface,
              color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            codeblockDecoration: BoxDecoration(
              color: isUser ? colorScheme.primary.withOpacity(0.15) : colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            h1: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
            h2: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            h3: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
            blockquote: TextStyle(color: textColor.withOpacity(0.8), fontStyle: FontStyle.italic, fontSize: 15),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: isUser ? colorScheme.onPrimary.withOpacity(0.5) : colorScheme.primary.withOpacity(0.5), width: 4),
              ),
            ),
            listBullet: TextStyle(color: textColor, fontSize: 15),
          ),
        );
      } catch (e) {
        // Fallback to simple selectable text if markdown throws an error
        return SelectableText(textContent, style: TextStyle(color: textColor, fontSize: 15, height: 1.4));
      }
    } else if (block is ToolCallBlock) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary.withOpacity(0.15) : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isUser ? colorScheme.onPrimary.withOpacity(0.1) : colorScheme.primary.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal_rounded, size: 16, color: isUser ? colorScheme.onPrimary : colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  block.toolName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isUser ? colorScheme.onPrimary : colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUser ? colorScheme.primary.withOpacity(0.1) : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Parameters: ${block.parameters}', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: textColor)),
            ),
            if (block.result != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUser ? colorScheme.primary.withOpacity(0.08) : colorScheme.surfaceVariant.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Result:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: textColor)),
                    const SizedBox(height: 4),
                    Text(
                      '${block.result}',
                      style: TextStyle(fontFamily: 'monospace', fontSize: this.message.role == Role.user ? 12 : 13, color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      return const Text('Unsupported message type');
    }
  }
}

// Blinking cursor animation for the typing indicator
class _BlinkingCursor extends StatefulWidget {
  final Color color;

  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: Container(color: widget.color, width: 2, height: 16));
  }
}
