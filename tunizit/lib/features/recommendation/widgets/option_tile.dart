import 'package:material_ui/material_ui.dart';
import '../../../core/theme.dart';
import '../data/form_options.dart';

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.help,
    this.icon,
  });

  final String label;
  final String? help;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? AppColors.oliveSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.olive : AppColors.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected ? null : AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.olive : AppColors.oliveSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected ? Colors.white : AppColors.olive,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (help != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            help!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.olive),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Un titre + une liste de grosses tuiles de choix.
class OptionGroup extends StatelessWidget {
  const OptionGroup({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.optional = false,
  });

  final String title;
  final List<Opt> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
            color: AppColors.olive,
          ),
        ),
        const SizedBox(height: 8),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OptionTile(
              label: o.label,
              help: o.help,
              icon: o.icon,
              selected: value == o.value,
              onTap: () {
                if (value == o.value && optional) {
                  onChanged(null);
                } else {
                  onChanged(o.value);
                }
              },
            ),
          ),
      ],
    );
  }
}