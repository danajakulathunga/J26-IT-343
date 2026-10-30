import 'package:flutter/material.dart';

class MarketTrendsScreen extends StatelessWidget {
  const MarketTrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market Trends')),
      body: const Center(
        child: Text('Placeholder for price/demand charts (using fl_chart)'),
      ),
    );
  }
}
