import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_lang.dart';
import '../services/class_service.dart';
import '../services/device_service.dart';

/// دوبارہ استعمال ہونے والا بٹن جو محفوظ طریقے سے کلاس جوائن کرتا ہے۔
class JoinClassButton extends StatefulWidget {
  final String classId;
  final String? label;

  const JoinClassButton({
    super.key,
    required this.classId,
    this.label,
  });

  @override
  State<JoinClassButton> createState() => _JoinClassButtonState();
}

class _JoinClassButtonState extends State<JoinClassButton> {
  final ClassService _service = ClassService();
  bool _loading = false;

  Future<void> _onPressed() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final deviceId = await DeviceService.getDeviceId();
      final result = await _service.joinClass(
        classId: widget.classId,
        deviceId: deviceId,
      );
      if (!mounted) return;
      if (result.success) {
        _showZoomDialog(result.zoomLink!);
      } else {
        _showMessage(result.message!, isError: true);
      }
    } catch (e) {
      if (mounted) _showMessage('${L.t('خرابی', 'Error')}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// کامیاب جوائن پر ایک بٹن دکھائیں
  void _showZoomDialog(String link) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          L.t('کلاس تیار ہے! ✅', 'Class Ready! ✅'),
          textAlign: TextAlign.center,
        ),
        content: Text(
          L.t(
            'زوم ایپ ڈاونلوڈ کر کے انسٹال کریں۔ بغیر زوم ایپ کے آپ کلاس میں شامل نہیں ہو سکتے۔',
            'Download and install the Zoom app. You cannot join the class without the Zoom app.',
          ),
          textAlign: TextAlign.center,
        ),
        actionsOverflowButtonSpacing: 6,
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L.t('بند کریں', 'Close')),
          ),
          TextButton.icon(
            icon: const Icon(Icons.download),
            label: Text(L.t('Zoom ڈاونلوڈ کریں', 'Download Zoom')),
            onPressed: () {
              Navigator.pop(context);
              _openZoomDownload();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam),
            label: Text(L.t('کلاس میں شامل ہوں', 'Join Class')),
            onPressed: () async {
              Navigator.pop(context);
              await _openZoom(link);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openZoom(String link) async {
    final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    if (isMobile) {
      final uri = Uri.tryParse(link.trim());
      if (uri == null || !uri.isAbsolute) {
        _promptInstallZoom();
        return;
      }
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }
      if (!launched) _promptInstallZoom();
    } else {
      final deep = _toZoomAppLink(link);
      if (deep == null) {
        _promptInstallZoom();
        return;
      }
      try {
        await launchUrl(deep, mode: LaunchMode.externalApplication);
      } catch (_) {
        _promptInstallZoom();
      }
    }
  }

  Uri? _toZoomAppLink(String link) {
    try {
      final u = Uri.parse(link.trim());
      final segs = u.pathSegments;
      String? confno;
      final jIndex = segs.indexOf('j');
      if (jIndex != -1 && jIndex + 1 < segs.length) {
        confno = segs[jIndex + 1];
      } else {
        for (final s in segs.reversed) {
          if (RegExp(r'^\d{5,}$').hasMatch(s)) {
            confno = s;
            break;
          }
        }
      }
      if (confno == null || confno.isEmpty) return null;
      final pwd = u.queryParameters['pwd'] ?? '';
      final sb =
          StringBuffer('zoommtg://zoom.us/join?action=join&confno=$confno');
      if (pwd.isNotEmpty) sb.write('&pwd=$pwd');
      return Uri.parse(sb.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _openZoomDownload() async {
    await launchUrl(
      Uri.parse('https://zoom.us/download'),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  void _promptInstallZoom() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          L.t('Zoom app درکار ہے', 'Zoom app required'),
          textAlign: TextAlign.center,
        ),
        content: Text(
          L.t(
            'زوم ایپ ڈاونلوڈ کر کے انسٹال کریں۔ بغیر زوم ایپ کے آپ کلاس میں شامل نہیں ہو سکتے۔',
            'Download and install the Zoom app. You cannot join the class without the Zoom app.',
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L.t('بند کریں', 'Close')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: Text(L.t('Zoom ڈاونلوڈ کریں', 'Download Zoom')),
            onPressed: () {
              Navigator.pop(context);
              _openZoomDownload();
            },
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.videocam_rounded),
        label: Text(
          widget.label ?? L.t('کلاس میں شامل ہوں', 'Join Class'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E9F91),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _loading ? null : _onPressed,
      ),
    );
  }
}
