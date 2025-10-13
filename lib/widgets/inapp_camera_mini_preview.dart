import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class InAppCameraMiniPreview extends StatelessWidget {
  final CameraController controller;
  const InAppCameraMiniPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 160,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: controller.value.isInitialized
            ? CameraPreview(controller)
            : const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
