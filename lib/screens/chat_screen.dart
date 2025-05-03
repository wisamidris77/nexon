import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/message.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:nexon/screens/conversation_detail_screen.dart';
import 'package:nexon/components/chat_history_sidebar.dart';

// Temporary chat ID provider - no database entry until first message
final temporaryChatProvider = StateProvider<bool>((ref) => false);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-create new chat on first load if there's no current conversation
    if (!_initialized) {
      _initialized = true;

      // Check if we already have a conversation selected
      final currentId = ref.read(currentConversationIdProvider);
      if (currentId == null) {
        // Load existing conversations
        ref.read(conversationsProvider.future).then((conversations) {
          if (conversations.isEmpty) {
            // Create a new temporary chat if there are no existing conversations
            _createNewConversation();
          } else {
            // Select the most recent conversation
            ref.read(currentConversationIdProvider.notifier).state = conversations.first.id;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentConversationId = ref.watch(currentConversationIdProvider);
    final isTemporaryChat = ref.watch(temporaryChatProvider);
    final isLargeScreen = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Nexon AI Chat'),
        leading:
            isLargeScreen
                ? null
                : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
        actions: [
          // Only show settings button if sidebar is not visible (mobile)
          if (!isLargeScreen)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                // Use named route to avoid hero animation conflict
                Navigator.of(context).pushNamed('/settings');
              },
            ),
        ],
      ),
      drawer: isLargeScreen ? null : ChatHistorySidebar(onNewChat: _createNewConversation),
      body: Row(
        children: [
          // Always show sidebar on large screens
          if (isLargeScreen) SizedBox(width: 280, child: ChatHistorySidebar(onNewChat: _createNewConversation)),

          // Main chat area
          Expanded(child: _buildChatScreen(currentConversationId, isTemporaryChat)),
        ],
      ),
    );
  }

  Widget _buildChatScreen(String? conversationId, bool isTemporaryChat) {
    if (conversationId == null && !isTemporaryChat) {
      return _buildLoadingScreen(context);
    }

    return ConversationDetailScreen(conversationId: conversationId, isTemporary: isTemporaryChat, onFirstMessageSent: _handleFirstMessageSent);
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  void _createNewConversation() {
    // Set state to temporary chat (not saved in database yet)
    ref.read(currentConversationIdProvider.notifier).state = null;
    ref.read(temporaryChatProvider.notifier).state = true;

    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _handleFirstMessageSent(String conversationId) {
    // Once the first message is sent and a real conversation is created,
    // update the state to use the real conversation
    ref.read(currentConversationIdProvider.notifier).state = conversationId;
    ref.read(temporaryChatProvider.notifier).state = false;
  }
}
