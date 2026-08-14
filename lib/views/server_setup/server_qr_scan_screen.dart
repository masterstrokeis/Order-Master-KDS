import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/server_address.dart';

class ServerQrScanOutcome {
  const ServerQrScanOutcome._({this.ipAddress, this.port, this.invalid = false});

  const ServerQrScanOutcome.invalid() : this._(invalid: true);

  const ServerQrScanOutcome.values({
    required String ipAddress,
    required String port,
  }) : this._(ipAddress: ipAddress, port: port);

  final String? ipAddress;
  final String? port;
  final bool invalid;
}

class ServerQrScanScreen extends StatefulWidget {
  const ServerQrScanScreen({super.key});

  @override
  State<ServerQrScanScreen> createState() => _ServerQrScanScreenState();
}

class _ServerQrScanScreenState extends State<ServerQrScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chromeHeader,
      appBar: AppBar(
        backgroundColor: AppColors.chromeHeader,
        foregroundColor: AppColors.onStatusHeader,
        title: Text(
          'Scan server QR',
          style: AppTextStyles.headlineMd.copyWith(
            color: AppColors.onStatusHeader,
          ),
        ),
      ),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (_handled) {
            return;
          }
          String? raw;
          for (final Barcode barcode in capture.barcodes) {
            final String? value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              raw = value;
              break;
            }
          }
          if (raw == null) {
            return;
          }
          _handled = true;
          final ({String ipAddress, String port})? parsed =
              parseServerQrPayload(raw);
          if (!mounted) {
            return;
          }
          Navigator.of(context).pop(
            parsed == null
                ? const ServerQrScanOutcome.invalid()
                : ServerQrScanOutcome.values(
                    ipAddress: parsed.ipAddress,
                    port: parsed.port,
                  ),
          );
        },
      ),
    );
  }
}
