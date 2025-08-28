import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  VoidCallback? _completionHandler;
  Function(String)? _onStatusChange;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  /// Set status change callback
  void setStatusChangeCallback(Function(String) callback) {
    _onStatusChange = callback;
  }

  /// Initialize speech services
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        throw Exception('Microphone permission denied');
      }

      // Initialize Speech to Text
      final sttAvailable = await _speechToText.initialize(
        onError: (error) {
          debugPrint('STT Error: $error');
          _isListening = false;
          _onStatusChange?.call('error');
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');

          // Update listening state based on actual STT status
          switch (status) {
            case "listening":
              _isListening = true;
              _onStatusChange?.call('listening');
              break;
            case "notListening":
            case "done":
              _isListening = false;
              _onStatusChange?.call('done');
              break;
            default:
              _isListening = false;
              _onStatusChange?.call('stopped');
          }
        },
      );

      if (!sttAvailable) {
        throw Exception('Speech recognition not available');
      }

      // Initialize Text to Speech
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set TTS callbacks
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _completionHandler?.call();
      });

      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
        _completionHandler?.call();
        debugPrint('TTS Error: $message');
      });

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Speech service initialization error: $e');
      return false;
    }
  }

  /// Start listening for speech input
  Future<void> startListening({
    Function(String)? onPartialResult,
    required Function(String) onResult,
    required Function(String) onError,
    String localeId = 'en_US',
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError('Speech recognition not available');
        return;
      }
    }

    // Stop any existing listening session
    if (_isListening) {
      await stopListening();
      // Wait a bit before starting new session
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      _isListening = true;
      _onStatusChange?.call('starting');

      await _speechToText.listen(
        onResult: (result) {
          debugPrint(
            'STT Result: ${result.recognizedWords}, Final: ${result.finalResult}, Confidence: ${result.confidence}',
          );

          // Handle partial results
          if (!result.finalResult && result.recognizedWords.isNotEmpty) {
            onPartialResult?.call(result.recognizedWords);
          }

          // Handle final results
          if (result.finalResult) {
            _isListening = true;
            onResult(result.recognizedWords);
            _isListening = false;
            _onStatusChange?.call('completed');
          }
        },
        listenFor: const Duration(seconds: 30), // Extended listening time
        pauseFor: const Duration(seconds: 5), // Longer pause tolerance
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false, // Don't cancel on minor errors
          listenMode: ListenMode.confirmation, // Better for longer phrases
        ),
      );
    } catch (e) {
      _isListening = false;
      _onStatusChange?.call('error');
      onError('Failed to start listening: $e');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    _isListening = false;
    _onStatusChange?.call('stopped');
  }

  /// Speak text using TTS
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isSpeaking) {
      await stop();
    }

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  /// Stop TTS
  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
    }
  }

  /// Set completion handler for TTS
  void setCompletionHandler(VoidCallback handler) {
    _completionHandler = handler;
  }

  /// Get available languages for STT
  Future<List<LocaleName>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speechToText.locales();
  }

  /// Check if speech recognition is available
  Future<bool> isAvailable() async {
    return await _speechToText.initialize();
  }

  /// Dispose resources
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    _isInitialized = false;
    _isListening = false;
    _isSpeaking = false;
  }
}
