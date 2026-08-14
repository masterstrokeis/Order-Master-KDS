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
  String? _error;

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
      });
      return;
    }
    setState(() {
      _ipController.text = outcome.ipAddress!;
      _portController.text = outcome.port!;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final String ip = _ipController.text.trim();
    final String port = _portController.text.trim();
    final String? validation = validateServerAddress(
      ipAddress: ip,
      port: port,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
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
                    enabled: !_saving,
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
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8000',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.gutter),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.pageMargin),
                  SizedBox(
                    height: AppSpacing.touchTargetMin,
                    child: ElevatedButton(
                      key: const Key('server-save-button'),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Checking…' : 'Save'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  OutlinedButton.icon(
                    key: const Key('server-qr-button'),
                    onPressed: _saving ? null : _scanQr,
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
