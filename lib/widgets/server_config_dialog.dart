import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';

/// Shows an interactive Server Connection dialog with live connectivity test (ping)
/// and persistence to local storage.
void showServerConfigDialog(BuildContext context, {VoidCallback? onApplied}) {
  var currentUrl = storageService.getCustomServerUrl() ?? AppConstants.defaultApiBaseUrl;
  if (currentUrl.contains('localhost') || currentUrl.contains('trycloudflare.com')) {
    currentUrl = AppConstants.defaultLocalIpUrl;
  }
  final controller = TextEditingController(text: currentUrl);

  showDialog(
    context: context,
    builder: (ctx) => _ServerConfigDialogContent(
      controller: controller,
      onApplied: onApplied,
    ),
  );
}

class _ServerConfigDialogContent extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onApplied;

  const _ServerConfigDialogContent({
    required this.controller,
    this.onApplied,
  });

  @override
  State<_ServerConfigDialogContent> createState() => _ServerConfigDialogContentState();
}

class _ServerConfigDialogContentState extends State<_ServerConfigDialogContent> {
  bool _isTesting = false;
  String? _testMessage;
  bool _testSuccess = false;

  Future<void> _testConnection() async {
    final testUrl = widget.controller.text.trim();
    if (testUrl.isEmpty) {
      setState(() {
        _testMessage = 'Please enter a valid URL';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    try {
      var clean = testUrl;
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }

      final tempDio = Dio(
        BaseOptions(
          baseUrl: clean,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final response = await tempDio.get('/health');
      if (response.statusCode == 200) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testMessage = '✅ Server reachable! (Status 200 OK)';
        });
      } else {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testMessage = '⚠️ Server returned HTTP ${response.statusCode}';
        });
      }
    } on DioException catch (e) {
      String msg;
      if (testUrl.contains('trycloudflare.com')) {
        msg = '❌ Cloudflare Tunnel expired or inactive. Click "Reset to Localhost" below!';
      } else if (e.response?.statusCode == 530) {
        msg = '❌ HTTP 530: Cloudflare Tunnel expired. Click "Reset to Localhost"!';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = '⏱️ Connection timed out. Ensure backend is running.';
      } else {
        msg = '❌ Connection failed (${e.message ?? 'unreachable'}). Ensure backend is running.';
      }
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testMessage = msg;
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testMessage = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: AppConstants.primaryLightGreen),
          SizedBox(width: 8),
          Text(
            'Server Connection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend API URL (Cloudflare Tunnel or Local IP):',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.controller,
              decoration: InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://....trycloudflare.com',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded),
                  tooltip: 'Paste from Clipboard',
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      widget.controller.text = data.text!.trim();
                      _testConnection();
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && data!.text!.trim().isNotEmpty) {
                    widget.controller.text = data.text!.trim();
                    _testConnection();
                  }
                },
                icon: const Icon(Icons.cloud_done_rounded, size: 16),
                label: const Text('Paste Cloudflare URL (For Dialog / Mobitel)', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Quick Network Presets:',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wifi, size: 14),
                  label: const Text('192.168.1.172', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    widget.controller.text = 'http://192.168.1.172:8000';
                    _testConnection();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.wifi, size: 14),
                  label: const Text('192.168.8.233', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    widget.controller.text = 'http://192.168.8.233:8000';
                    _testConnection();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.school, size: 14),
                  label: const Text('172.28.9.58 (SLIIT)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    widget.controller.text = 'http://172.28.9.58:8000';
                    _testConnection();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.computer, size: 14),
                  label: const Text('localhost:8000', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    widget.controller.text = 'http://localhost:8000';
                    _testConnection();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      widget.controller.text = AppConstants.defaultLocalIpUrl;
                      _testConnection();
                    },
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text(
                      'Reset to Default IP',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 16),
                  label: const Text(
                    'Test Ping',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _testSuccess
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess ? Colors.green : Colors.redAccent,
                  ),
                ),
                child: Text(
                  _testMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _testSuccess ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            var newUrl = widget.controller.text.trim();
            while (newUrl.endsWith('/')) {
              newUrl = newUrl.substring(0, newUrl.length - 1);
            }
            if (newUrl.isNotEmpty) {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await storageService.setCustomServerUrl(newUrl);
              apiClient.updateBaseUrl(newUrl);
              if (!mounted) return;
              navigator.pop();
              widget.onApplied?.call();

              messenger.showSnackBar(
                SnackBar(
                  content: Text('Server URL set to: $newUrl'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}
