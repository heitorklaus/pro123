// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:mavis/products/presentation/widgets/automation_preview_bridge.dart';

/// Implementação Web Real com Google `<model-viewer>` (Three.js WebGL Engine)
class GlbModelViewerWidget extends StatefulWidget {
  final String? glbUrl;
  final String? fallbackImageUrl;
  final bool autoRotate;
  final Color accentColor;
  final double glbScale;
  final double glbOrbitTheta;
  final double glbOrbitPhi;
  final bool enableCameraControls;
  final void Function(double thetaDeg, double phiDeg)? onCameraChange;

  const GlbModelViewerWidget({
    super.key,
    this.glbUrl,
    this.fallbackImageUrl,
    this.autoRotate = true,
    this.accentColor = const Color(0xFF00E5FF),
    this.glbScale = 1.2,
    this.glbOrbitTheta = 45.0,
    this.glbOrbitPhi = 65.0,
    this.enableCameraControls = true,
    this.onCameraChange,
  });

  static Map<String, double>? getCurrentCameraOrbit() {
    try {
      final el = html.document.querySelector('model-viewer');
      if (el != null) {
        final dynamic mv = el;
        final dynamic orbit = mv.getCameraOrbit();
        if (orbit != null) {
          final double rawTheta = _extractAngleDegreesStatic(orbit.theta);
          final double rawPhi = _extractAngleDegreesStatic(orbit.phi);
          final double thetaDeg = ((rawTheta) % 360 + 360) % 360;
          final double phiDeg = rawPhi.clamp(10.0, 90.0);
          return {'theta': thetaDeg, 'phi': phiDeg};
        }
      }
    } catch (_) {}
    return null;
  }

  static double _extractAngleDegreesStatic(dynamic prop) {
    if (prop == null) return 0.0;
    if (prop is num) {
      return (prop.toDouble() * 180.0 / 3.141592653589793);
    }
    try {
      final dynamic val = prop.value;
      if (val != null) {
        final double numVal = val is num ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
        final String unit = prop.unit?.toString() ?? 'rad';
        if (unit == 'deg') return numVal;
        return numVal * 180.0 / 3.141592653589793;
      }
    } catch (_) {}
    try {
      final String s = prop.toString();
      final match = RegExp(r'([0-9.-]+)\s*(deg|rad)?').firstMatch(s);
      if (match != null) {
        final double val = double.parse(match.group(1)!);
        final unit = match.group(2);
        if (unit == 'deg') return val;
        return val * 180.0 / 3.141592653589793;
      }
    } catch (_) {}
    return 0.0;
  }

  @override
  State<GlbModelViewerWidget> createState() => _GlbModelViewerWidgetState();
}

class _GlbModelViewerWidgetState extends State<GlbModelViewerWidget> {
  late String _viewTypeId;
  static final Set<String> _registeredTypes = {};
  String _effectiveGlbSrc = '';
  html.Element? _modelElement;

  @override
  void initState() {
    super.initState();
    _ensureModelViewerScript();
    _resolveAndRegisterSrc();
  }

  @override
  void didUpdateWidget(covariant GlbModelViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glbUrl != widget.glbUrl) {
      _resolveAndRegisterSrc();
    } else {
      _updateModelViewerAttributes(oldWidget);
    }
  }

  void _updateModelViewerAttributes(GlbModelViewerWidget oldWidget) {
    final el = _modelElement ?? html.document.querySelector('model-viewer');
    if (el == null) return;

    if (oldWidget.autoRotate != widget.autoRotate) {
      if (widget.autoRotate) {
        el.setAttribute('auto-rotate', '');
      } else {
        el.removeAttribute('auto-rotate');
      }
    }

    if (oldWidget.enableCameraControls != widget.enableCameraControls) {
      if (widget.enableCameraControls) {
        el.setAttribute('camera-controls', '');
        el.setAttribute('touch-action', 'pan-y');
        el.removeAttribute('disable-zoom');
        el.removeAttribute('disable-pan');
        el.removeAttribute('disable-tap');
        el.style.pointerEvents = 'auto';
      } else {
        el.removeAttribute('camera-controls');
        el.setAttribute('disable-zoom', '');
        el.setAttribute('disable-pan', '');
        el.setAttribute('disable-tap', '');
        el.style.pointerEvents = 'none';
      }
    }

    if (oldWidget.glbScale != widget.glbScale ||
        oldWidget.glbOrbitTheta != widget.glbOrbitTheta ||
        oldWidget.glbOrbitPhi != widget.glbOrbitPhi) {
      final thetaStr = widget.glbOrbitTheta.toStringAsFixed(1);
      final phiStr = widget.glbOrbitPhi.toStringAsFixed(1);
      final orbitDist = (80 / widget.glbScale.clamp(0.4, 4.0)).round();

      el.setAttribute('scale', '${widget.glbScale} ${widget.glbScale} ${widget.glbScale}');
      el.setAttribute('camera-orbit', '${thetaStr}deg ${phiStr}deg $orbitDist%');

      try {
        final dynamic mv = el;
        mv.scale = '${widget.glbScale} ${widget.glbScale} ${widget.glbScale}';
        mv.cameraOrbit = '${thetaStr}deg ${phiStr}deg $orbitDist%';
      } catch (_) {}
    }
  }

  void _ensureModelViewerScript() {
    try {
      if (html.document.querySelector('script[src*="model-viewer"]') == null) {
        final script = html.ScriptElement()
          ..type = 'module'
          ..src = 'https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js';
        html.document.head?.append(script);
      }
    } catch (_) {}
  }

  static final Map<String, String> _blobUrlCache = {};

  Future<String?> _fetchRemoteGlbAsBlobUrl(String url) async {
    if (_blobUrlCache.containsKey(url)) {
      return _blobUrlCache[url];
    }

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final blob = html.Blob([res.bodyBytes], 'model/gltf-binary');
        final blobUrl = '${html.Url.createObjectUrlFromBlob(blob)}#model.glb';
        _blobUrlCache[url] = blobUrl;
        return blobUrl;
      }
    } catch (_) {}

    try {
      final proxy1 = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(url)}');
      final res = await http.get(proxy1);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final blob = html.Blob([res.bodyBytes], 'model/gltf-binary');
        final blobUrl = '${html.Url.createObjectUrlFromBlob(blob)}#model.glb';
        _blobUrlCache[url] = blobUrl;
        return blobUrl;
      }
    } catch (_) {}

    try {
      final proxy2 = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}');
      final res = await http.get(proxy2);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final blob = html.Blob([res.bodyBytes], 'model/gltf-binary');
        final blobUrl = '${html.Url.createObjectUrlFromBlob(blob)}#model.glb';
        _blobUrlCache[url] = blobUrl;
        return blobUrl;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _resolveAndRegisterSrc() async {
    String src = widget.glbUrl?.trim() ?? '';
    if (src.isEmpty || src.startsWith('indexeddb:')) {
      src = AutomationPreviewBridge.latestGlbDataUrl ?? '';
    }

    if (src.isEmpty || src.startsWith('indexeddb:')) {
      final fromDb = await AutomationPreviewBridge.get3DModelBlobUrl();
      if (fromDb != null && fromDb.isNotEmpty) {
        src = fromDb;
      }
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      final localBlob = await _fetchRemoteGlbAsBlobUrl(src);
      if (localBlob != null && localBlob.isNotEmpty) {
        src = localBlob;
        AutomationPreviewBridge.latestGlbDataUrl = localBlob;
      }
    }

    if (mounted) {
      setState(() {
        _effectiveGlbSrc = src;
        _registerViewFactory();
      });
    }
  }



  void _handleCameraChange(html.Element element) {
    try {
      final dynamic mv = element;
      final dynamic orbit = mv.getCameraOrbit();
      if (orbit != null) {
        final double rawTheta = GlbModelViewerWidget._extractAngleDegreesStatic(orbit.theta);
        final double rawPhi = GlbModelViewerWidget._extractAngleDegreesStatic(orbit.phi);
        final double thetaDeg = ((rawTheta) % 360 + 360) % 360;
        final double phiDeg = rawPhi.clamp(10.0, 90.0);
        widget.onCameraChange?.call(thetaDeg, phiDeg);
      }
    } catch (_) {}
  }

  void _registerViewFactory() {
    if (_effectiveGlbSrc.isEmpty || _effectiveGlbSrc.startsWith('indexeddb:')) return;

    final thetaStr = widget.glbOrbitTheta.toStringAsFixed(1);
    final phiStr = widget.glbOrbitPhi.toStringAsFixed(1);
    _viewTypeId = 'model-viewer-${_effectiveGlbSrc.hashCode}';

    if (!_registeredTypes.contains(_viewTypeId)) {
      _registeredTypes.add(_viewTypeId);

      ui_web.platformViewRegistry.registerViewFactory(_viewTypeId, (int viewId) {
        String effectiveSrc = _effectiveGlbSrc;
        if (effectiveSrc.startsWith('data:')) {
          try {
            final comma = effectiveSrc.indexOf(',');
            final base64Part = comma != -1 ? effectiveSrc.substring(comma + 1) : effectiveSrc;
            final bytes = base64Decode(base64Part);
            final blob = html.Blob([bytes], 'model/gltf-binary');
            effectiveSrc = '${html.Url.createObjectUrlFromBlob(blob)}#model.glb';
          } catch (_) {
            effectiveSrc = _effectiveGlbSrc;
          }
        } else if (effectiveSrc.startsWith('blob:') && !effectiveSrc.contains('#model.glb')) {
          effectiveSrc = '$effectiveSrc#model.glb';
        }

        final orbitDist = (80 / widget.glbScale.clamp(0.4, 4.0)).round();
        final element = html.Element.tag('model-viewer')
          ..setAttribute('src', effectiveSrc)
          ..setAttribute('alt', 'Maquete 3D Interativa da Residência')
          ..setAttribute('shadow-intensity', '1.6')
          ..setAttribute('shadow-softness', '0.7')
          ..setAttribute('exposure', '1.1')
          ..setAttribute('camera-orbit', '${thetaStr}deg ${phiStr}deg $orbitDist%')
          ..setAttribute('min-camera-orbit', 'auto auto 2%')
          ..setAttribute('max-camera-orbit', 'auto auto 500%')
          ..setAttribute('scale', '${widget.glbScale} ${widget.glbScale} ${widget.glbScale}')
          ..setAttribute('loading', 'eager')
          ..setAttribute('reveal', 'auto')
          ..setAttribute('interaction-prompt', 'none')
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = 'transparent'
          ..style.outline = 'none';

        if (widget.enableCameraControls) {
          element
            ..setAttribute('camera-controls', '')
            ..setAttribute('touch-action', 'pan-y');
        } else {
          element
            ..setAttribute('disable-zoom', '')
            ..setAttribute('disable-pan', '')
            ..setAttribute('disable-tap', '')
            ..style.pointerEvents = 'none';
        }

        _modelElement = element;

        element.addEventListener('camera-change', (html.Event evt) {
          _handleCameraChange(element);
        });

        if (widget.autoRotate) {
          element
            ..setAttribute('auto-rotate', '')
            ..setAttribute('auto-rotate-delay', '1200')
            ..setAttribute('rotation-per-second', '14deg');
        }

        return element;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveGlbSrc.isEmpty || _effectiveGlbSrc.startsWith('indexeddb:')) {
      return _buildFallbackImage();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(
          key: ValueKey(_viewTypeId),
          viewType: _viewTypeId,
        ),
      ],
    );
  }

  Widget _buildFallbackImage() {
    if (widget.fallbackImageUrl != null && widget.fallbackImageUrl!.isNotEmpty) {
      final imgUrl = widget.fallbackImageUrl!;
      if (imgUrl.startsWith('data:')) {
        final comma = imgUrl.indexOf(',');
        final bytes = base64Decode(comma != -1 ? imgUrl.substring(comma + 1) : imgUrl);
        return Image.memory(bytes, fit: BoxFit.contain);
      }
      if (imgUrl.startsWith('assets/')) {
        return Image.asset(imgUrl, fit: BoxFit.contain);
      }
      return Image.network(imgUrl, fit: BoxFit.contain);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_in_ar_rounded, size: 64, color: widget.accentColor),
          const SizedBox(height: 12),
          Text(
            'Carregando maquete 3D...',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
