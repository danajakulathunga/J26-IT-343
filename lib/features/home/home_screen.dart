import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ceylon Export Field Kit'),
        actions: [
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF266E4E),
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
            tooltip: 'Account & Field Kit Screens',
            onSelected: (val) {
              if (val.isNotEmpty) context.push(val);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: '/splash',
                child: Row(
                  children: [
                    Icon(Icons.eco, color: Color(0xFF266E4E), size: 18),
                    SizedBox(width: 10),
                    Text('Field Kit Welcome (Splash)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: '/onboarding',
                child: Row(
                  children: [
                    Icon(Icons.view_carousel, color: Color(0xFF266E4E), size: 18),
                    SizedBox(width: 10),
                    Text('Onboarding Tour'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: '/login',
                child: Row(
                  children: [
                    Icon(Icons.login, color: Color(0xFF266E4E), size: 18),
                    SizedBox(width: 10),
                    Text('Log In Screen'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: '/register',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1, color: Color(0xFF266E4E), size: 18),
                    SizedBox(width: 10),
                    Text('Create Account Screen'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: '/identification/admin-models',
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFF266E4E), size: 18),
                    SizedBox(width: 10),
                    Text('Admin Model Center'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
          if (constraints.maxWidth > 1000) {
            crossAxisCount = 4;
          }
          
          return GridView.count(
            crossAxisCount: crossAxisCount,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _FeatureCard(
                title: 'Fruit Identification',
                icon: Icons.search,
                color: Colors.orange,
                onTap: () => context.push('/identification'),
              ),
              _FeatureCard(
                title: 'Defect Detection',
                icon: Icons.bug_report,
                color: Colors.red,
                onTap: () => context.push('/defect-detection'),
              ),
              _FeatureCard(
                title: 'Shelf-Life Prediction',
                icon: Icons.access_time,
                color: Colors.blue,
                onTap: () => context.push('/shelf-life'),
              ),
              _FeatureCard(
                title: 'Traceability',
                icon: Icons.qr_code,
                color: Colors.purple,
                onTap: () => context.push('/traceability'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
