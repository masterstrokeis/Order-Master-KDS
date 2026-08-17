import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/server_address.dart';
import '../../models/server_config.dart';
import '../../providers/server_config_providers.dart';
import '../../services/connection_check.dart';
import '../login/login_screen.dart';
import 'server_qr_scan_screen.dart';

Future<ConnectionCheckResult> _defaultConnectionCheck(String baseUrl) {
  return checkKdsConnection(baseUrl: baseUrl);
}

class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({
    super.key,
    this.fromSettings = false,
    this.checkConnection = _defaultConnectionCheck,
  });

  final bool fromSettings;
  final Future<ConnectionCheckResult> Function(String baseUrl) checkConnection;

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  bool _saving = false;
  bool _testing = false;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final ServerConfig? existing = ref.read(serverConfigProvider);
    _ipController = TextEditingController(text: existing?.ipAddress ?? '');
    _portController = TextEditingController(text: existing?.port ?? '');
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final ServerQrScanOutcome? outcome =
        await Navigator.of(context).push<ServerQrScanOutcome>(
          MaterialPageRoute<ServerQrScanOutcome>(
            builder: (_) => const ServerQrScanScreen(),
          ),
        );
    if (!mounted || outcome == null) {
      return;
    }
    if (outcome.invalid ||
        outcome.ipAddress == null ||
        outcome.port == null) {
      setState(() {
        _error = 'QR code is missing ip_address and port_number.';
        _statusMessage = null;
      });
      return;
    }
    setState(() {
      _ipController.text = outcome.ipAddress!;
      _portController.text = outcome.port!;
      _error = null;
      _statusMessage = null;
    });
  }

  Future<void> _testConnection() async {
    if (_saving || _testing) {
      return;
    }
    final String ip = _ipController.text.trim();
    final String port = _portController.text.trim();
    final String? validation = validateServerAddress(
      ipAddress: ip,
      port: port,
    );
    if (validation != null) {
      setState(() {
        _error = validation;
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _testing = true;
      _error = null;
      _statusMessage = null;
    });

    final ServerConfig config = ServerConfig(ipAddress: ip, port: port);
    final ConnectionCheckResult check = await widget.checkConnection(
      config.baseUrl,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _testing = false;
      if (check.ok) {
        _statusMessage = 'Connected';
        _error = null;
      } else {
        _statusMessage = null;
        _error = check.errorMessage ?? 'Could not reach the server.';
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _testing) {
      return;
    }
    final String ip = _ipController.text.trim();
    final String port = _portController.text.trim();
    final String? validation = validateServerAddress(
      ipAddress: ip,
      port: port,
    );
    if (validation != null) {
      setState(() {
        _error = validation;
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _statusMessage = null;
    });

    final ServerConfig config = ServerConfig(ipAddress: ip, port: port);
    final ConnectionCheckResult check = await widget.checkConnection(
      config.baseUrl,
    );
    if (!mounted) {
      return;
    }
    if (!check.ok) {
      setState(() {
        _saving = false;
        _error = check.errorMessage ?? 'Could not reach the server.';
      });
      return;
    }

    await ref.read(serverConfigServiceProvider).save(config);
    await ref.read(authControllerProvider.notifier).logout();
    ref.read(serverConfigProvider.notifier).state = config;

    if (widget.fromSettings) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
        ),
        (Route<dynamic> route) => false,
      );
      return;
    }

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _saving || _testing;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.fromSettings
          ? AppBar(
              backgroundColor: AppColors.chromeHeader,
              foregroundColor: AppColors.onStatusHeader,
              title: Text(
                'Server',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.onStatusHeader,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.touchTargetMin * 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Server address',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineMd.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  Text(
                    'Enter the kitchen server IP and port, or scan a QR code.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.pageMargin),
                  TextField(
                    key: const Key('server-ip-field'),
                    controller: _ipController,
                    keyboardType: TextInputType.number,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'IP address',
                      hintText: '192.168.1.100',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  TextField(
                    key: const Key('server-port-field'),
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8000',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.gutter),
                    Text(
                      key: const Key('server-error-text'),
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: AppSpacing.gutter),
                    Text(
                      key: const Key('server-status-text'),
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.pageMargin),
                  SizedBox(
                    height: AppSpacing.touchTargetMin,
                    child: OutlinedButton(
                      key: const Key('server-test-button'),
                      onPressed: busy ? null : _testConnection,
                      child: Text(_testing ? 'Testing…' : 'Test connection'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  SizedBox(
                    height: AppSpacing.touchTargetMin,
                    child: ElevatedButton(
                      key: const Key('server-save-button'),
                      onPressed: busy ? null : _save,
                      child: Text(_saving ? 'Checking…' : 'Save'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  OutlinedButton.icon(
                    key: const Key('server-qr-button'),
                    onPressed: busy ? null : _scanQr,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSpacing.touchTargetMin,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppRadii.defaultRadius,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('QR Scan'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
