import 'package:dio/dio.dart';
import '../models/message.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  late final Dio _dio;
  final String _apiKey;

  GeminiService({required String apiKey}) : _apiKey = apiKey {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Add interceptor for logging
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print(obj),
      ),
    );
  }

  /// Generate content using Gemini API
  Future<String> generateContent({
    required String prompt,
    List<Message>? conversationHistory,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '/models/gemini-2.0-flash:generateContent?key=$_apiKey',
          data: {
            'contents': _buildContents(prompt, conversationHistory),
            'generationConfig': {
              'temperature': 0.7,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': 1024,
            },
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              },
            ],
          },
        );

        if (response.statusCode == 200) {
          final data = response.data;
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final content = data['candidates'][0]['content'];
            if (content != null &&
                content['parts'] != null &&
                content['parts'].isNotEmpty) {
              return content['parts'][0]['text'] ?? 'No response generated.';
            }
          }
          throw Exception('No valid response from Gemini API');
        } else {
          throw Exception(
            'HTTP ${response.statusCode}: ${response.statusMessage}',
          );
        }
      } on DioException catch (e) {
        if (attempt == maxRetries - 1) {
          throw _handleDioError(e);
        }
        // Wait before retrying
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      } catch (e) {
        if (attempt == maxRetries - 1) {
          throw Exception('Unexpected error: $e');
        }
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }
    throw Exception('Failed after $maxRetries attempts');
  }

  /// Build contents array for the API request
  List<Map<String, dynamic>> _buildContents(
    String prompt,
    List<Message>? history,
  ) {
    final contents = <Map<String, dynamic>>[];

    // Add conversation history (last 10 messages for context)
    if (history != null && history.isNotEmpty) {
      final recentHistory = history.length > 10
          ? history.sublist(history.length - 10)
          : history;

      for (final message in recentHistory) {
        if (!message.isError) {
          contents.add({
            'role': message.role == MessageRole.user ? 'user' : 'model',
            'parts': [
              {'text': message.text},
            ],
          });
        }
      }
    }

    // Add current prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt},
      ],
    });

    return contents;
  }

  /// Handle Dio errors with user-friendly messages
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception(
          'Connection timeout. Please check your internet connection.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        switch (statusCode) {
          case 400:
            return Exception('Invalid request. Please try again.');
          case 401:
            return Exception(
              'Invalid API key. Please check your configuration.',
            );
          case 403:
            return Exception(
              'Access forbidden. Please check your API permissions.',
            );
          case 429:
            return Exception(
              'Rate limit exceeded. Please wait a moment and try again.',
            );
          case 500:
            return Exception('Server error. Please try again later.');
          default:
            return Exception(
              'HTTP $statusCode: ${e.response?.statusMessage ?? 'Unknown error'}',
            );
        }
      case DioExceptionType.cancel:
        return Exception('Request was cancelled.');
      case DioExceptionType.unknown:
        return Exception(
          'Network error. Please check your internet connection.',
        );
      default:
        return Exception('An unexpected error occurred: ${e.message}');
    }
  }
}
