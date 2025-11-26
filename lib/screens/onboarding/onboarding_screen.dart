import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/locale_service.dart';
import '../../widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final slides = [
    (
      'onb_title_1'.tr(),
      'onb_desc_1'.tr(),
      Icons.sports_martial_arts,
    ),
    (
      'onb_title_2'.tr(),
      'onb_desc_2'.tr(),
      Icons.health_and_safety,
    ),
    (
      'onb_title_3'.tr(),
      'onb_desc_3'.tr(),
      Icons.bar_chart,
    ),
  ];

  Future<void> _finish() async {
    await LocaleService.setHasSeenOnboarding(true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, K.routeHome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text('skip'.tr()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = slides[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(s.$3, size: 96, color: AppColors.accentPurple),
                      const SizedBox(height: 24),
                      Text(s.$1, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(s.$2, textAlign: TextAlign.center),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _index == slides.length - 1 ? 'continue'.tr() : 'next'.tr(),
              onPressed: () {
                if (_index == slides.length - 1) {
                  _finish();
                } else {
                  _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: null,
    );
  }
}
