import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/models/message.dart';
import 'package:nexon/providers/conversation_provider.dart';
import 'package:nexon/screens/conversation_detail_screen.dart';
import 'package:nexon/components/chat_history_sidebar.dart';
import 'package:nexon/providers/settings_provider.dart';

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
  void initState() {
    super.initState();

    // Schedule the initialization logic for after the first frame
    // This prevents modifying state during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversation();
    });
  }

  // New method to safely initialize the conversation outside the build phase
  void _initializeConversation() {
    if (!_initialized) {
      _initialized = true;

      // Check app settings to determine if we should start with a new chat
      final appSettings = ref.read(settingsProvider);

      if (appSettings.startWithNewChat) {
        // Start with a new chat regardless of previous state
        _createNewConversation();
      } else {
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
  }

  @override
  Widget build(BuildContext context) {
    final currentConversationId = ref.watch(currentConversationIdProvider);
    final isTemporaryChat = ref.watch(temporaryChatProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1200;
    final isMediumScreen = screenWidth >= 800 && screenWidth < 1200;

    // Get current conversation title
    final conversationAsync = currentConversationId != null ? ref.watch(currentConversationProvider) : null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title:
            conversationAsync == null || isTemporaryChat
                ? const Text('Nexon AI Chat', style: TextStyle(fontWeight: FontWeight.w600))
                : conversationAsync.when(
                  data:
                      (conversation) => Text(
                        conversation != null ? 'Nexon AI Chat - ${conversation.title}' : 'Nexon AI Chat',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                  loading: () => const Text('Nexon AI Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                  error: (_, __) => const Text('Nexon AI Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        leading:
            isLargeScreen || isMediumScreen
                ? null
                : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
        actions: [
          // Only show settings button if sidebar is not visible (mobile)
          if (!isLargeScreen && !isMediumScreen)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).pushNamed('/settings');
              },
            ),
        ],
      ),
      drawer: isLargeScreen || isMediumScreen ? null : ChatHistorySidebar(onNewChat: _createNewConversation),
      floatingActionButton:
          !isLargeScreen && !isMediumScreen ? FloatingActionButton(onPressed: _createNewConversation, child: const Icon(Icons.add)) : null,
      body: Row(
        children: [
          // Always show sidebar on large/medium screens
          if (isLargeScreen || isMediumScreen)
            SizedBox(width: isLargeScreen ? 280 : 250, child: ChatHistorySidebar(onNewChat: _createNewConversation)),

          // Main chat area
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _buildChatScreen(currentConversationId, isTemporaryChat),
              ),
            ),
          ),
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
