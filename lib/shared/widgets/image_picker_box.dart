import 'package:flutter/material.dart';

class ImagePickerBox extends StatelessWidget {
  final VoidCallback onTap;
  final String title;

  const ImagePickerBox({
    super.key,
    required this.onTap,
    this.title = 'Tap to select an image',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
