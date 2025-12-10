import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/app_theme.dart';

class AiBuildEntryScreen extends StatefulWidget {
  const AiBuildEntryScreen({super.key});
  @override
  State<AiBuildEntryScreen> createState() => _AiBuildEntryScreenState();
}

class _AiBuildEntryScreenState extends State<AiBuildEntryScreen> {
  bool _navBusy = false;
  Widget _card(String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        if (_navBusy) return; _navBusy = true; onTap(); Future.delayed(const Duration(milliseconds: 400), (){ _navBusy = false; });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accentPurple, width: 1.4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children:[Container(width:40,height:40,decoration: BoxDecoration(color: AppColors.accentPurple,borderRadius: BorderRadius.circular(12))), const SizedBox(width:12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height:4), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary))]))]),
        ]),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Build Asistanı')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _card('Kahraman + Build', 'Kahraman seç, sana en uygun meta ve eğlenceli build önerisi çıksın.', (){ Navigator.pushReplacementNamed(context, K.routeAiHeroSelect); }),
          const SizedBox(height: 16),
          _card('Rastgele Build', 'Kahraman seçmeden rastgele bir build al.', (){ Navigator.pushReplacementNamed(context, K.routeAiRandomBuild); }),
        ]),
      ),
    );
  }
}
