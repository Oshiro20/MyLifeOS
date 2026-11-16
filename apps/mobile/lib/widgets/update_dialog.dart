import 'package:flutter/material.dart';
import '../services/mylifeos_update_service.dart';

class MyLifeOSUpdateDialog extends StatefulWidget {
  final GithubRelease release;
  final VoidCallback? onDismiss;

  const MyLifeOSUpdateDialog({
    super.key,
    required this.release,
    this.onDismiss,
  });

  @override
  State<MyLifeOSUpdateDialog> createState() => _MyLifeOSUpdateDialogState();
}

class _MyLifeOSUpdateDialogState extends State<MyLifeOSUpdateDialog> {
  double _progress = 0;
  bool _isDownloading = false;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final service = MyLifeOSUpdateService();
      await service.downloadAndInstall(
        url: widget.release.apkUrl,
        fileName: widget.release.fileName,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al descargar o instalar: $e';
        });
      }
    } finally {
      if (mounted && _isDownloading) {
        setState(() {
          _isDownloading = false;
          _progress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF152019) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A1F16);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF35594A);
    final subtleColor = isDark ? Colors.white54 : const Color(0xFF5D7A6E);
    final accentBlue =
        isDark ? const Color(0xFF00F0FF) : const Color(0xFF00796B);

    return PopScope(
      canPop: !_isDownloading,
      child: Dialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: _isDownloading
              ? _buildDownloadingState(textColor, mutedColor, subtleColor)
              : _buildUpdateAvailableState(
                  isDark, textColor, mutedColor, subtleColor, accentBlue),
        ),
      ),
    );
  }

  Widget _buildUpdateAvailableState(
    bool isDark,
    Color textColor,
    Color mutedColor,
    Color subtleColor,
    Color accentBlue,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF00E676), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '✨ Actualización disponible',
                style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Nueva versión ${widget.release.tagName}',
          style: TextStyle(color: accentBlue, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF0F9F5),
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Text(
              _formatReleaseNotes(widget.release.body),
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  widget.onDismiss?.call();
                  Navigator.of(context).pop();
                },
                child: Text('Después', style: TextStyle(color: subtleColor)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _startUpdate,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Actualizar ahora'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingState(
      Color textColor, Color mutedColor, Color subtleColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.downloading, color: Color(0xFF00E676), size: 48),
        const SizedBox(height: 24),
        Text(
          'Descargando actualización...',
          style: TextStyle(
              color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: subtleColor.withValues(alpha: 0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        Text(
          '${(_progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(color: mutedColor, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Text(
          'Se abrirá el instalador automáticamente',
          style: TextStyle(color: subtleColor, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatReleaseNotes(String body) {
    return body
        .replaceAll('## ', '')
        .replaceAll('### ', '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ');
  }
}

/// Función auxiliar para mostrar el diálogo
Future<void> showMyLifeOSUpdateDialog(
  BuildContext context,
  GithubRelease release, {
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => MyLifeOSUpdateDialog(
      release: release,
      onDismiss: onDismiss,
    ),
  );
}
