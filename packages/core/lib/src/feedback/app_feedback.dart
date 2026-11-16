import 'package:flutter/material.dart';

/// Mixin reutilizable para feedback visual — SnackBars y diálogo de confirmación.
/// Úsalo en cualquier ConsumerWidget o StatefulWidget que tenga un BuildContext.
mixin AppFeedback {
  // ── SnackBars ──────────────────────────────────────────────────────────────
  void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      color: const Color(0xFF4CAF50),
    );
  }

  void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      color: const Color(0xFFFF5252),
      duration: const Duration(seconds: 4),
    );
  }

  void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      color: const Color(0xFF7C4DFF),
    );
  }

  void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 2),
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor:
              isDark ? const Color(0xFF1E1E30) : theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ── Diálogo de confirmación ────────────────────────────────────────────────
  /// Muestra un diálogo modal de confirmación antes de eliminar.
  /// Devuelve `true` si el usuario confirma, `false` si cancela.
  Future<bool> showConfirmDelete(
    BuildContext context, {
    required String itemName,
    String? subtitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.delete_outline,
                  color: Color(0xFFFF5252), size: 22),
              const SizedBox(width: 10),
              Text(
                '¿Eliminar?',
                style:
                    TextStyle(color: onSurface, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itemName,
                style: TextStyle(
                  color: onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: onSurface.withValues(alpha: 0.65), fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.45), fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style:
                      TextStyle(color: onSurface.withValues(alpha: 0.55))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Eliminar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
