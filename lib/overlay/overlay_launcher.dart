import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayLauncher {
  static Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return false;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted == true) return true;
    final req = await FlutterOverlayWindow.requestPermission();
    return req == true;
  }

  /// 오버레이 켜기 (엔트리포인트 연결)
  static Future<void> openOverlay({
    int width = 180,
    int height = 240,
  }) async {
    final ok = await ensurePermission();
    if (!ok) {
      debugPrint('[Overlay] permission denied');
      return;
    }
    final active = await FlutterOverlayWindow.isActive();
    if (active == true) {
      debugPrint('[Overlay] already active');
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      alignment: OverlayAlignment.centerRight,
      width: width,
      height: height,
      overlayTitle: 'StayAwake',
      overlayContent: 'Camera overlay',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      // ★ 여기가 핵심: 오버레이용 엔트리 함수명
    );
  }

  static Future<bool> ensureVisible({
    int width = 180,
    int height = 240,
  }) async {
    final active = await FlutterOverlayWindow.isActive();
    if (active == true) {
      debugPrint('[Overlay] ensureVisible: already active');
      return true;
    }
    await openOverlay(width: width, height: height);
    return (await FlutterOverlayWindow.isActive()) == true;
  }

  static Future<void> closeOverlay() async {
    final active = await FlutterOverlayWindow.isActive();
    if (active == true) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }
}
