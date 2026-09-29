import 'dart:convert';

import 'package:camera/camera.dart';

import 'api.dart';

/// ★2026-09-29 老公要的：她想看你的时候，自己能调这台 iPhone 的前置摄像头看你。
///
/// 链路：电脑端发现她想看你 → 通过 WebSocket 喊一嗓子 {type:'eye'} →
/// 这里立刻用【前置】拍一张 → POST /api/eye 回传 → 电脑端把这张递到她眼前（真视觉）→ 她说她看到了什么。
///
/// 注意：iOS 不允许后台开摄像头 → 只有 App 在前台才会拍；不在前台就跳过，
/// 电脑端会自动退回她那两台固定摄像头（桌面 / 床），不会卡住。
class PhoneEye {
  static bool _busy = false;
  static bool get busy => _busy;

  /// 用前置拍一张并回传。返回 true = 电脑端收到了。
  static Future<bool> shootAndSend(Api api, {String why = ''}) async {
    if (_busy) return false;
    _busy = true;
    CameraController? ctl;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return false;
      CameraDescription pick = cams.first;
      for (final c in cams) {
        if (c.lensDirection == CameraLensDirection.front) {
          pick = c;
          break;
        }
      }
      ctl = CameraController(pick, ResolutionPreset.medium, enableAudio: false);
      await ctl.initialize();
      final shot = await ctl.takePicture();
      final bytes = await shot.readAsBytes();
      final r = await api.eyePush('data:image/jpeg;base64,${base64Encode(bytes)}', why: why);
      return r['ok'] == true;
    } catch (_) {
      return false;
    } finally {
      try {
        await ctl?.dispose();
      } catch (_) {}
      _busy = false;
    }
  }
}
