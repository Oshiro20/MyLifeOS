import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core/core.dart';

/// Pantalla de configuración de conexión con WalletAI.
///
/// Permite al usuario:
/// - Ver el estado de conexión actual
/// - Ver y copiar el Project ID
/// - Configurar un ID personalizado
/// - Forzar una sincronización
/// - Abrir WalletAI
class WalletAIConnectionSettingsScreen extends StatefulWidget {
  const WalletAIConnectionSettingsScreen({super.key});

  @override
  State<WalletAIConnectionSettingsScreen> createState() =>
      _WalletAIConnectionSettingsScreenState();
}

class _WalletAIConnectionSettingsScreenState
    extends State<WalletAIConnectionSettingsScreen> {
  WalletConnectionStatus? _connectionStatus;
  Map<String, dynamic>? _identityInfo;
  String? _cloudUsername;
  bool _loading = true;
  bool _syncing = false;
  bool _cloudAuthLoading = false;
  bool _isRegisterMode = false;
  final _customIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _customIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() => _loading = true);

    final status = await WalletAICommunicationService.checkConnectionStatus();
    final identity = await SharedIdentityService.getIdentityInfo();
    final customId = await SharedIdentityService.getWalletAICustomId();
    final cloudSession = await WalletCloudService.getSession();

    if (mounted) {
      setState(() {
        _connectionStatus = status;
        _identityInfo = identity;
        _cloudUsername = cloudSession.username;
        _customIdController.text = customId ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _authenticateCloud() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;
    if (user.length < 3 || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ingresa usuario (mín. 3 chars) y contraseña (mín. 6).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _cloudAuthLoading = true);
    final res = await WalletCloudService.authenticate(
      username: user,
      password: pass,
      isRegister: _isRegisterMode,
    );
    if (res.success) {
      _passwordController.clear();
      await WalletSummaryReader.read();
    }
    await _loadInfo();

    if (mounted) {
      setState(() => _cloudAuthLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor:
              res.success ? const Color(0xFF00C896) : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _signOutCloud() async {
    await WalletCloudService.signOut();
    await _loadInfo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión en WalletAI Cloud cerrada')),
      );
    }
  }

  Future<void> _forceSync() async {
    setState(() => _syncing = true);

    await WalletAICommunicationService.requestSync();
    await Future.delayed(const Duration(seconds: 2));
    await _loadInfo();

    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronización solicitada a WalletAI'),
          backgroundColor: Color(0xFF00C896),
        ),
      );
    }
  }

  Future<void> _saveCustomId() async {
    final customId = _customIdController.text.trim();

    if (customId.isEmpty) {
      await SharedIdentityService.setWalletAICustomId('');
    } else {
      await SharedIdentityService.setWalletAICustomId(customId);
    }

    await _loadInfo();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID personalizado guardado'),
          backgroundColor: Color(0xFF00C896),
        ),
      );
    }
  }

  Future<void> _resetIdentity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetear identidad'),
        content: const Text(
          '¿Estás seguro de que quieres resetear la identidad de esta app? '
          'Se generará un nuevo Project ID y perderás la conexión actual con WalletAI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SharedIdentityService.resetIdentity();
      await _loadInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identidad reseteada correctamente'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copiado al portapapeles'),
          backgroundColor: const Color(0xFF00C896),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF152019) : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexión con WalletAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Cuenta WalletAI en la Nube (Render)
                      _CloudAccountCard(
                        username: _cloudUsername,
                        isRegisterMode: _isRegisterMode,
                        loading: _cloudAuthLoading,
                        usernameController: _usernameController,
                        passwordController: _passwordController,
                        onToggleMode: () => setState(
                          () => _isRegisterMode = !_isRegisterMode,
                        ),
                        onAuthenticate: _authenticateCloud,
                        onSignOut: _signOutCloud,
                      ),
                      const SizedBox(height: 16),

                      // Estado de conexión
                      _ConnectionStatusCard(status: _connectionStatus),
                      const SizedBox(height: 16),

                      // Información de identidad
                      _IdentityInfoCard(
                        identityInfo: _identityInfo,
                        onCopy: _copyToClipboard,
                      ),
                      const SizedBox(height: 16),

                      // ID personalizado
                      Card(
                        color: surfaceColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ID Personalizado (Opcional)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Si configuraste un ID específico en WalletAI, ingrésalo aquí.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customIdController,
                                      decoration: const InputDecoration(
                                        hintText: 'Ej: mywallet123',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.tag),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _saveCustomId,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                    ),
                                    child: const Text('Guardar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Acciones
                      _ActionButtons(
                        onForceSync: _forceSync,
                        onOpenWalletAI: _openWalletAI,
                        onResetIdentity: _resetIdentity,
                        syncing: _syncing,
                      ),
                      const SizedBox(height: 32),

                      // Información adicional
                      Card(
                        color: surfaceColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '¿Cómo funciona?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _InfoStep(
                                number: 1,
                                title: 'Generación de Project ID',
                                description:
                                    'MyLifeOS genera un Project ID único automáticamente.',
                              ),
                              const SizedBox(height: 8),
                              _InfoStep(
                                number: 2,
                                title: 'Configuración en WalletAI',
                                description:
                                    'Abre WalletAI y configura el mismo Project ID en Ajustes > Integración.',
                              ),
                              const SizedBox(height: 8),
                              _InfoStep(
                                number: 3,
                                title: 'Sincronización',
                                description:
                                    'Ambas apps compartirán datos financieros de forma segura.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openWalletAI() async {
    await WalletAICommunicationService.openWalletAI();
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda - Conexión con WalletAI'),
        content: const SingleChildScrollView(
          child: Text(
            'Para conectar MyLifeOS con WalletAI:\n\n'
            '1. Ambas apps deben compartir el mismo Project ID\n'
            '2. El Project ID se genera automáticamente\n'
            '3. Puedes configurar un ID personalizado en WalletAI > Ajustes > Integración\n'
            '4. Luego ingresa ese ID aquí y guarda\n'
            '5. Finalmente, abre WalletAI para sincronizar los datos\n\n'
            'Si tienes problemas:\n'
            '- Asegúrate de que ambas apps están actualizadas\n'
            '- Verifica que el Project ID sea el mismo en ambas apps\n'
            '- Intenta forzar una sincronización\n'
            '- Como último recurso, resetea la identidad',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

/// Card de estado de conexión
class _ConnectionStatusCard extends StatelessWidget {
  final WalletConnectionStatus? status;

  const _ConnectionStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConnected = status?.isConnected ?? false;
    final isMatched = status?.isProjectIdMatched ?? false;

    Color borderColor;
    IconData icon;
    String title;
    String subtitle;

    if (!isConnected) {
      borderColor = const Color(0xFFFF6B6B);
      icon = Icons.link_off;
      title = 'No conectado';
      subtitle = status?.error ?? 'WalletAI no está conectado';
    } else if (!isMatched) {
      borderColor = const Color(0xFFF59E0B);
      icon = Icons.warning_amber;
      title = 'Project IDs no coinciden';
      subtitle = status?.getStatusMessage() ?? 'Verifica la configuración';
    } else {
      borderColor = const Color(0xFF00C896);
      icon = Icons.check_circle;
      title = 'Conectado';
      subtitle = status?.getStatusMessage() ?? 'Sincronizado correctamente';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: borderColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de información de identidad
class _IdentityInfoCard extends StatelessWidget {
  final Map<String, dynamic>? identityInfo;
  final Function(String, String) onCopy;

  const _IdentityInfoCard({
    required this.identityInfo,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (identityInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final projectId = identityInfo!['projectId'] as String;
    final userId = identityInfo!['userId'] as String;
    final sharingCode = identityInfo!['sharingCode'] as String;
    final createdAt = identityInfo!['createdAt'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de Identidad',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            _IdentityField(
              label: 'Project ID',
              value: projectId,
              icon: Icons.fingerprint,
              onCopy: () => onCopy(projectId, 'Project ID'),
            ),
            const SizedBox(height: 12),
            _IdentityField(
              label: 'User ID',
              value: userId,
              icon: Icons.person,
              onCopy: () => onCopy(userId, 'User ID'),
            ),
            const SizedBox(height: 12),
            _IdentityField(
              label: 'Código de Compartición',
              value: sharingCode,
              icon: Icons.qr_code,
              onCopy: () => onCopy(sharingCode, 'Código'),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Creado: ${DateTime.parse(createdAt).day}/${DateTime.parse(createdAt).month}/${DateTime.parse(createdAt).year}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Campo de identidad con botón de copiar
class _IdentityField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onCopy;

  const _IdentityField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 20, color: onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          onPressed: onCopy,
          tooltip: 'Copiar',
        ),
      ],
    );
  }
}

/// Botones de acción
class _ActionButtons extends StatelessWidget {
  final VoidCallback onForceSync;
  final VoidCallback onOpenWalletAI;
  final VoidCallback onResetIdentity;
  final bool syncing;

  const _ActionButtons({
    required this.onForceSync,
    required this.onOpenWalletAI,
    required this.onResetIdentity,
    required this.syncing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: syncing ? null : onForceSync,
          icon: syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(syncing ? 'Sincronizando...' : 'Forzar Sincronización'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C896),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onOpenWalletAI,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir WalletAI'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onResetIdentity,
          icon: const Icon(Icons.refresh, color: Color(0xFFFF6B6B)),
          label: const Text(
            'Resetear Identidad',
            style: TextStyle(color: Color(0xFFFF6B6B)),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF6B6B)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Paso informativo
class _InfoStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const _InfoStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF00C896).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF00C896),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CloudAccountCard extends StatelessWidget {
  final String? username;
  final bool isRegisterMode;
  final bool loading;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onToggleMode;
  final VoidCallback onAuthenticate;
  final VoidCallback onSignOut;

  const _CloudAccountCard({
    required this.username,
    required this.isRegisterMode,
    required this.loading,
    required this.usernameController,
    required this.passwordController,
    required this.onToggleMode,
    required this.onAuthenticate,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF152019) : Colors.white;
    final isSignedIn = username != null && username!.isNotEmpty;

    return Card(
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSignedIn ? Icons.cloud_done : Icons.cloud_sync,
                  color: isSignedIn ? const Color(0xFF00C896) : Colors.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSignedIn
                        ? 'WalletAI Cloud vinculado ($username)'
                        : 'Vincular Cuenta WalletAI (Nube)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isSignedIn
                  ? 'MyLifeOS lee categorías, actividad semanal y movimientos reales desde Render y puede enviar gastos a WalletAI.'
                  : 'Usa el mismo usuario y contraseña que configuraste en WalletAI > Respaldos para saltar las restricciones del sandbox Android.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 12),
            if (isSignedIn)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Desvincular cuenta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                    side: const BorderSide(color: Color(0xFFFF6B6B)),
                  ),
                ),
              )
            else ...[
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Usuario o correo WalletAI',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : onAuthenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C896),
                        foregroundColor: Colors.black,
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isRegisterMode
                              ? 'Crear Cuenta'
                              : 'Iniciar Sesión'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: loading ? null : onToggleMode,
                    child: Text(isRegisterMode ? 'Ya tengo cuenta' : 'Crear'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
