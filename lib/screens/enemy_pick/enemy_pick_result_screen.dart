import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../widgets/primary_button.dart';
import '../../models/hero_model.dart';
import 'enemy_pick_screen.dart';

class EnemyPickResultScreen extends StatefulWidget {
  const EnemyPickResultScreen({super.key});

  @override
  State<EnemyPickResultScreen> createState() => _EnemyPickResultScreenState();
}

class _EnemyPickResultScreenState extends State<EnemyPickResultScreen> {

  String _imageForHero(HeroModel h, BuildContext context) {
    // Stateless widget: image is resolved synchronously for now; UI uses placeholder if not yet available.
    switch (h.id) {
      case 'fanny':
        return 'https://lh3.googleusercontent.com/aida-public/AB6AXuBd1_eXFgWP28Yc5k7-bEAqDjI9H0iJQwY3J9FJVns4V3yNX3cp-tvV2ono9NpAGPkb_Q-hTacRyDS8IOwIIV1pxk0ZVPJtKOvgUPKtZmOx8c_MYjOkPBzW2685MRr1BcV0CjVFNaHrDWgpklMKMlnjiD-Kvuf37mZ5PIeQSTOMsLZzPzITmxcXZGWch5apx7N68h_le0GesA4fzMevFb4YIX1_lljiR3UvYHUC3MEzdwJAk2oarBuWQXOuGsFeDjGTJ05PW5BMb2TV';
      case 'miya':
        return 'https://via.placeholder.com/300x300.png?text=Miya';
      case 'tigreal':
        return 'https://via.placeholder.com/300x300.png?text=Tigreal';
      default:
        return 'https://via.placeholder.com/300x300.png?text=${h.name(Localizations.localeOf(context).languageCode)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final HeroSuggestion suggestion = ModalRoute.of(context)!.settings.arguments as HeroSuggestion;
    final alternatives = suggestion.alternativeHeroes;
    return Scaffold(
      appBar: AppBar(title: Text('enemy_pick_title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Benim counterlarım neler?', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Main hero’nu seç, sana karşı güçlü olan kahramanları ve dikkat etmen gereken noktaları gösterelim.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _counterCard(context, suggestion.suggestedHero, suggestion.shortReason, suggestion.difficulty),
          const SizedBox(height: 12),
          ...List.generate(alternatives.length, (i) {
            final h = alternatives[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _counterCard(context, h, 'generic_reason'.tr(), 'Orta'),
            );
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.tips_and_updates, color: AppColors.primary), const SizedBox(width: 8), Text('tactics'.tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              _bullet(context, suggestion.earlyGamePlan),
              _bullet(context, suggestion.midGamePlan),
              _bullet(context, suggestion.lateGamePlan),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: PrimaryButton(label: 'ask_new'.tr(), onPressed: () => Navigator.pushReplacementNamed(context, K.routeEnemyPick))),
            const SizedBox(width: 12),
            Expanded(child: PrimaryButton(label: 'go_home'.tr(), onPressed: () => Navigator.pushNamedAndRemoveUntil(context, K.routeHome, (r) => false))),
          ]),
        ]),
      ),
      bottomNavigationBar: null,
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle, color: Colors.white70, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70))),
    ]);
  }

  Widget _counterCard(BuildContext context, HeroModel hero, String subtitle, String difficulty) {
    Color badgeColor;
    switch (difficulty.toLowerCase()) {
      case 'kolay':
      case 'easy':
        badgeColor = Colors.green;
        break;
      case 'orta':
      case 'medium':
        badgeColor = Colors.yellow;
        break;
      case 'zor':
      case 'hard':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = AppColors.accentPurple;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF271C27), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF543B54))),
      child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: AppColors.primary, backgroundImage: NetworkImage(_imageForHero(hero, context))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hero.name(Localizations.localeOf(context).languageCode), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ])),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: Text(difficulty, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
