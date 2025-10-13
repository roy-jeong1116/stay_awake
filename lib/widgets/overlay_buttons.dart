// lib/widgets/overlay_buttons.dart
import 'package:flutter/material.dart';
import '../overlay/overlay_launcher.dart';

class OverlayButtons extends StatefulWidget {
  const OverlayButtons({super.key});

  @override
  State<OverlayButtons> createState() => _OverlayButtonsState();
}

class _OverlayButtonsState extends State<OverlayButtons> {
  bool _opening = false;
  bool _closing = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final ok = await OverlayLauncher.ensurePermission();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오버레이 권한이 필요합니다. 설정에서 허용해주세요.')),
        );
        return;
      }
      await OverlayLauncher.openOverlay();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오버레이 열기 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      await OverlayLauncher.closeOverlay();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오버레이 닫기 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'open_overlay_fab',
          onPressed: _opening ? null : _open,
          tooltip: '오버레이 열기',
          child: _opening
              ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.open_in_new),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.small(
          heroTag: 'close_overlay_fab',
          backgroundColor: Colors.red,
          onPressed: _closing ? null : _close,
          tooltip: '오버레이 닫기',
          child: _closing
              ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }
}
