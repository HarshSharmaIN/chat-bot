import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/chat.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';

// State classes
class ChatState {
  final List<Chat> chats;
  final String? currentChatId;
  final List<Message> messages;
  final bool isLoading;
  final bool isListening;
  final bool isSpeaking;
  final String recognizedText;
  final String? error;

  const ChatState({
    this.chats = const [],
    this.currentChatId,
    this.messages = const [],
    this.isLoading = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.recognizedText = '',
    this.error,
  });

  ChatState copyWith({
    List<Chat>? chats,
    String? currentChatId,
    List<Message>? messages,
    bool? isLoading,
    bool? isListening,
    bool? isSpeaking,
    String? recognizedText,
    String? error,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      currentChatId: currentChatId ?? this.currentChatId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      recognizedText: recognizedText ?? this.recognizedText,
      error: error,
    );
  }
}

// Providers
final geminiServiceProvider = Provider<GeminiService>((ref) {
  const apiKey = 'ENTER_YOUR_API_KEY';
  return GeminiService(apiKey: apiKey);
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final geminiService = ref.read(geminiServiceProvider);
  final speechService = ref.read(speechServiceProvider);
  return ChatNotifier(geminiService, speechService);
});

// Chat Notifier
class ChatNotifier extends StateNotifier<ChatState> {
  final GeminiService _geminiService;
  final SpeechService _speechService;
  final Box<Message> _messageBox = Hive.box<Message>('messages');
  final Box<Chat> _chatBox = Hive.box<Chat>('chats');
  final Uuid _uuid = const Uuid();

  ChatNotifier(this._geminiService, this._speechService)
    : super(const ChatState()) {
    _loadChats();
    _initializeSpeechService();
  }

  /// Load chats from local storage
  void _loadChats() {
    final chats = _chatBox.values.toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(chats: chats);
  }

  /// Load messages for current chat
  void _loadMessagesForChat(String chatId) {
    final chat = _chatBox.get(chatId);
    if (chat == null) return;

    final messages = <Message>[];
    for (final messageId in chat.messageIds) {
      final message = _messageBox.get(messageId);
      if (message != null) {
        messages.add(message);
      }
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(messages: messages);
  }

  /// Create a new chat
  String createNewChat() {
    final chatId = _uuid.v4();
    final chat = Chat(
      id: chatId,
      title: 'New Chat',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messageIds: [],
    );

    _chatBox.put(chatId, chat);
    final updatedChats = List<Chat>.from(state.chats)..insert(0, chat);
    state = state.copyWith(
      chats: updatedChats,
      currentChatId: chatId,
      messages: [],
    );

    return chatId;
  }

  /// Set current chat
  void setCurrentChat(String chatId) {
    state = state.copyWith(currentChatId: chatId);
    _loadMessagesForChat(chatId);
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    final chat = _chatBox.get(chatId);
    if (chat == null) return;

    // Delete all messages in the chat
    for (final messageId in chat.messageIds) {
      await _messageBox.delete(messageId);
    }

    // Delete the chat
    await _chatBox.delete(chatId);

    // Update state
    final updatedChats = state.chats.where((c) => c.id != chatId).toList();
    state = state.copyWith(chats: updatedChats);

    // If this was the current chat, clear messages
    if (state.currentChatId == chatId) {
      state = state.copyWith(currentChatId: null, messages: []);
    }
  }

  /// Rename a chat
  Future<void> renameChat(String chatId, String newTitle) async {
    final chat = _chatBox.get(chatId);
    if (chat == null) return;

    final updatedChat = chat.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );

    await _chatBox.put(chatId, updatedChat);

    final updatedChats = state.chats.map((c) {
      return c.id == chatId ? updatedChat : c;
    }).toList();

    state = state.copyWith(chats: updatedChats);
  }

  /// Update chat title based on first message
  Future<void> _updateChatTitle(String chatId, String firstMessage) async {
    final chat = _chatBox.get(chatId);
    if (chat == null || chat.messageIds.length > 2) {
      return; // Only update for new chats
    }

    // Generate a title from the first message (first 30 characters)
    String title = firstMessage.trim();
    if (title.length > 30) {
      title = '${title.substring(0, 30)}...';
    }

    final updatedChat = chat.copyWith(title: title, updatedAt: DateTime.now());

    await _chatBox.put(chatId, updatedChat);

    final updatedChats = state.chats.map((c) {
      return c.id == chatId ? updatedChat : c;
    }).toList();

    state = state.copyWith(chats: updatedChats);
  }

  /// Initialize speech service
  Future<void> _initializeSpeechService() async {
    await _speechService.initialize();

    // Set up status change callback to sync state
    _speechService.setStatusChangeCallback((status) {
      switch (status) {
        case 'listening':
          if (mounted) {
            state = state.copyWith(isListening: true);
          }
          break;
        case 'done':
        case 'stopped':
        case 'completed':
        case 'error':
          if (mounted) {
            state = state.copyWith(isListening: false);
          }
          break;
      }
    });
  }

  /// Send a text message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Ensure we have a current chat
    String chatId = state.currentChatId ?? createNewChat();

    final userMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    // Add user message
    await _addMessage(userMessage, chatId);

    // Set loading state
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get AI response
      final response = await _geminiService.generateContent(
        prompt: text.trim(),
        conversationHistory: state.messages,
      );

      final assistantMessage = Message(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        text: response,
        timestamp: DateTime.now(),
      );

      await _addMessage(assistantMessage, chatId);
    } catch (e) {
      final errorMessage = Message(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        text: 'Sorry, I encountered an error: ${e.toString()}',
        timestamp: DateTime.now(),
        isError: true,
      );

      await _addMessage(errorMessage, chatId);
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Add message to state and storage
  Future<void> _addMessage(Message message, String chatId) async {
    await _messageBox.put(message.id, message);

    // Update chat with new message
    final chat = _chatBox.get(chatId);
    if (chat != null) {
      final updatedMessageIds = List<String>.from(chat.messageIds)
        ..add(message.id);
      final updatedChat = chat.copyWith(
        messageIds: updatedMessageIds,
        updatedAt: DateTime.now(),
      );
      await _chatBox.put(chatId, updatedChat);

      // Update chat title if this is the first user message
      if (message.role == MessageRole.user && chat.messageIds.isEmpty) {
        await _updateChatTitle(chatId, message.text);
      }

      // Update chats list in state
      final updatedChats = state.chats.map((c) {
        return c.id == chatId ? updatedChat : c;
      }).toList();
      updatedChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(chats: updatedChats);
    }

    final updatedMessages = List<Message>.from(state.messages)..add(message);
    state = state.copyWith(messages: updatedMessages);
  }

  Future<void> startVoiceInput() async {
    // Clear any previous text and errors
    state = state.copyWith(recognizedText: '', error: null);

    await _speechService.startListening(
      onPartialResult: (text) {
        if (mounted) {
          state = state.copyWith(recognizedText: text);
        }
      },
      onResult: (text) {
        if (mounted) {
          state = state.copyWith(isListening: false, recognizedText: text);
        }
      },
      onError: (error) {
        if (mounted) {
          // Don't close modal on "no match" errors - allow retry
          if (error.contains('error_no_match')) {
            state = state.copyWith(
              isListening: false,
              // Keep existing recognized text if any
            );
          } else {
            state = state.copyWith(
              isListening: false,
              recognizedText: '',
              error: 'Voice input error: $error',
            );
          }
        }
      },
    );
  }

  /// Stop voice input
  Future<void> stopVoiceInput() async {
    await _speechService.stopListening();
    state = state.copyWith(isListening: false);
  }

  /// Send recognized text from voice input
  void sendRecognizedText() {
    final text = state.recognizedText.trim();
    if (text.isNotEmpty) {
      state = state.copyWith(recognizedText: '');
      sendMessage(text);
    }
  }

  /// Clear recognized text
  void clearRecognizedText() {
    state = state.copyWith(recognizedText: '');
  }

  /// Speak message using TTS
  Future<void> speakMessage(String text) async {
    if (state.isSpeaking) {
      await _speechService.stop();
      state = state.copyWith(isSpeaking: false);
      return;
    }

    state = state.copyWith(isSpeaking: true);

    try {
      await _speechService.speak(text);

      // Set up a listener for TTS completion
      _speechService.setCompletionHandler(() {
        if (mounted) {
          state = state.copyWith(isSpeaking: false);
        }
      });
    } catch (e) {
      state = state.copyWith(isSpeaking: false);
    }

    // Fallback to ensure state is updated
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_speechService.isSpeaking) {
        state = state.copyWith(isSpeaking: false);
      }
    });
  }

  /// Clear all messages
  Future<void> clearMessages() async {
    if (state.currentChatId != null) {
      await deleteChat(state.currentChatId!);
    }
  }

  /// Delete a specific message
  Future<void> deleteMessage(String messageId) async {
    await _messageBox.delete(messageId);
    final updatedMessages = state.messages
        .where((m) => m.id != messageId)
        .toList();
    state = state.copyWith(messages: updatedMessages);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }
}
