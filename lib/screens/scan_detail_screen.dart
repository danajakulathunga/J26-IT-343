import 'package:flutter/material.dart';
import 'package:bananaguard_ai/models/scan_result.dart';
import 'package:bananaguard_ai/services/scan_service.dart';
import 'package:bananaguard_ai/screens/result_screen.dart';

class ScanDetailScreen extends StatefulWidget {
  final String scanId;

  const ScanDetailScreen({super.key, required this.scanId});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  ScanResultModel? _scanResult;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScan();
  }

  Future<void> _loadScan() async {
    try {
      final scan = await scanService.getScanById(widget.scanId);
      if (mounted) {
        setState(() {
          _scanResult = scan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load scan details';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _scanResult == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Detail')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error ?? 'Scan not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadScan,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Reuse full production results screen presentation
    return ResultScreen(scanResult: _scanResult);
  }
}
