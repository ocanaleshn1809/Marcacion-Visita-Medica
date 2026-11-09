import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';

class UnitSelectorSheet extends StatelessWidget {
  const UnitSelectorSheet({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Elige tu espacio',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona la unidad y el rol con el que trabajarás hoy.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 18),
              ...controller.availableUnits.map(
                (access) => _AccessTile(
                  access: access,
                  enabled: !controller.isBusy,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final selected = await controller.chooseUnit(access);
                    if (selected && navigator.mounted) navigator.pop();
                  },
                ),
              ),
              if (controller.isBusy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessTile extends StatelessWidget {
  const _AccessTile({required this.access, required this.enabled, this.onTap});

  final UnitAccess access;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        tileColor: AppColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF26372F)),
        ),
        leading: const CircleAvatar(
          backgroundColor: AppColors.forest,
          foregroundColor: AppColors.mint,
          child: Icon(Icons.badge_outlined),
        ),
        title: Text(
          access.unitName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(access.roleName),
        trailing: const Icon(Icons.arrow_forward_rounded),
      ),
    );
  }
}
