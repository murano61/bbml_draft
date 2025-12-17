import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class FiveAnalysisEmptyScreen extends StatelessWidget {
  final VoidCallback onSelectFive;
  const FiveAnalysisEmptyScreen({super.key, required this.onSelectFive});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('5’li Analiz')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          const Text('Takımını seç ve analizi başlat', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('5 farklı koridor için kahraman seçerek güç analizi ve önerileri görebilirsin.', style: TextStyle(color: Colors.white70)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onSelectFive, child: const Text('5 Kahraman Seç')),
          ),
        ]),
      ),
    );
  }
}
