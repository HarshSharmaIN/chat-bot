import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VoiceInputModal extends StatefulWidget {
  final bool isListening;
  final String recognizedText;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final VoidCallback onRetry;

  const VoiceInputModal({
    super.key,
    required this.isListening,
    required this.recognizedText,
    required this.onCancel,
    required this.onSend,
    required this.onRetry,
  });

  @override
  State<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends State<VoiceInputModal>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceInputModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Voice animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: widget.isListening ? null : widget.onRetry,
                      child: Container(
                        width: 120 * _pulseAnimation.value,
                        height: 120 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isListening
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : theme.colorScheme.error.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isListening
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error.withValues(
                                      alpha: 0.7,
                                    ),
                            ),
                            child: Icon(
                              widget.isListening ? Icons.mic : Icons.mic_off,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).animate().scale(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                ),

                const SizedBox(height: 40),

                // Status text
                Text(
                  widget.isListening
                      ? 'Listening...'
                      : widget.recognizedText.isEmpty
                      ? 'Tap to try again'
                      : 'Speech recognized',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 400)),

                const SizedBox(height: 20),

                // Recognized text display
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(minHeight: 100),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.recognizedText.isEmpty
                          ? 'Your speech will appear here...'
                          : widget.recognizedText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: widget.recognizedText.isEmpty
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ).animate().slideY(
                  begin: 0.3,
                  end: 0.0,
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 600),
                ),

                const Spacer(),

                // Action buttons
                if (widget.recognizedText.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel button
                      ElevatedButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),

                      // Send button
                      ElevatedButton.icon(
                        onPressed: widget.onSend,
                        icon: const Icon(Icons.send),
                        label: const Text('Send'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ).animate().slideY(
                    begin: 0.5,
                    end: 0.0,
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 800),
                  ),
                ] else ...[
                  // Instructions
                  Text(
                    widget.recognizedText.isEmpty
                        ? 'Tap the microphone to start speaking'
                        : 'Tap the microphone to try again',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: const Duration(milliseconds: 800)),
                ],

                SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
              ],
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
          ],
        ),
      ),
    );
  }
}
