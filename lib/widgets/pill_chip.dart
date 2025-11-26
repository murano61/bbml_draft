import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const PillChip({super.key, required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(
            side: BorderSide(color: AppColors.accentPink, width: 1.2),
          ),
          color: selected ? AppColors.accentPink : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

