import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../constants.dart';

class ArViewerPage extends StatelessWidget {
  final String modelUrl;
  final String productName;

  const ArViewerPage({
    super.key,
    required this.modelUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(productName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppColors.surface,
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              "Tap the AR icon below, then point your camera at a flat surface like the floor.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )),
          ]),
        ),
        Expanded(
          child: ModelViewer(
            src: modelUrl,
            alt: productName,
            ar: true,
            arModes: const ['scene-viewer', 'webxr', 'quick-look'],
            autoRotate: true,
            cameraControls: true,
            backgroundColor: AppColors.background,
          ),
        ),
      ]),
    );
  }
}