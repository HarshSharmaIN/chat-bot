import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final Function(String) onQuickAction;

  const QuickActions({super.key, required this.onQuickAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Grid of quick action buttons
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.5,
            children: [
              _buildQuickActionButton(
                context,
                icon: Icons.checklist,
                label: 'Create Todo',
                onTap: () =>
                    onQuickAction('Create a simple todo list for today'),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.lightbulb_outline,
                label: 'Get Ideas',
                onTap: () => onQuickAction(
                  'Give me 5 creative ideas for a weekend project',
                ),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.restaurant,
                label: 'Recipe Ideas',
                onTap: () => onQuickAction(
                  'Suggest a quick and healthy recipe for dinner',
                ),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.fitness_center,
                label: 'Workout Plan',
                onTap: () =>
                    onQuickAction('Create a 15-minute home workout routine'),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.school,
                label: 'Learn Something',
                onTap: () => onQuickAction(
                  'Teach me something interesting in 2 minutes',
                ),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.travel_explore,
                label: 'Travel Tips',
                onTap: () => onQuickAction(
                  'Give me travel tips for planning a weekend getaway',
                ),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.psychology,
                label: 'Fun Facts',
                onTap: () => onQuickAction(
                  'Tell me 3 fascinating facts I probably don\'t know',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Suggested prompts
          Text(
            'Suggested Prompts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPromptChip(context, 'Explain quantum physics simply'),
              _buildPromptChip(context, 'Write a short story'),
              _buildPromptChip(context, 'Help me debug code'),
              _buildPromptChip(context, 'Plan my day'),
              _buildPromptChip(context, 'Meditation guide'),
              _buildPromptChip(context, 'Language practice'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptChip(BuildContext context, String prompt) {
    final theme = Theme.of(context);

    return ActionChip(
      label: Text(prompt, style: theme.textTheme.bodySmall),
      onPressed: () => onQuickAction(prompt),
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
