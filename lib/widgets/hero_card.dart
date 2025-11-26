import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/hero_model.dart';

class HeroCard extends StatelessWidget {
  final HeroModel hero;
  final String? subtitle;
  final String? badge;
  const HeroCard({super.key, required this.hero, this.subtitle, this.badge});

  Color _badgeColor(String? b) {
    switch (b) {
      case 'Kolay':
      case 'easy':
        return AppColors.success;
      case 'Orta':
      case 'medium':
        return AppColors.warning;
      case 'Zor':
      case 'hard':
        return AppColors.danger;
      default:
        return AppColors.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.accentPurple,
            child: Text(hero.name(Localizations.localeOf(context).languageCode)[0]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hero.name(Localizations.localeOf(context).languageCode),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _badgeColor(badge),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

