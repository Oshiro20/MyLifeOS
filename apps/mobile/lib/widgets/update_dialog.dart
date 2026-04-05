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
        setState(() => _errorMessage = 'Error al descargar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF152019),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: _isDownloading
            ? _buildDownloadingState()
            : _buildUpdateAvailableState(),
      ),
    );
  }

  Widget _buildUpdateAvailableState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF00E676), size: 32),
            SizedBox(width: 12),
            Text(
              '✨ Actualización disponible',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Nueva versión ${widget.release.tagName}',
          style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Text(
              _formatReleaseNotes(widget.release.body),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                widget.onDismiss?.call();
                Navigator.of(context).pop();
              },
              child: const Text('Después',
                  style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(width: 8),
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
      ],
    );
  }

  Widget _buildDownloadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.downloading, color: Color(0xFF00E676), size: 48),
        const SizedBox(height: 24),
        const Text(
          'Descargando actualización...',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        Text(
          '${(_progress * 100).toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        const Text(
          'Se abrirá el instalador automáticamente',
          style: TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatReleaseNotes(String body) {
    // Limpiar el markdown básico
    return body
        .replaceAll('## ', '')
        .replaceAll('### ', '')
        .replaceAll('**', '')
        .replaceAll('* ', '• ')
        .replaceAll('-', '•');
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
