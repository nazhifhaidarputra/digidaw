import 'dart:ffi' as ffi;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:karbeat/core/widgets/plugin_parameter_widget.dart';
import 'package:karbeat/features/plugins/abstract_plugin_screen.dart'; // Unified base class
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;
import 'package:karbeat/src/rust/api/plugins/opaque.dart';
import 'package:karbeat/src/rust/api/plugins/types.dart';

/// Math helpers for Logarithmic Frequency Mapping
const double minFreq = 20.0;
const double maxFreq = 20000.0;
const double minGain = -24.0;
const double maxGain = 24.0;

double _freqToX(double freq, double width) {
  final minF = log(minFreq) / ln10;
  final maxF = log(maxFreq) / ln10;
  final val = log(freq.clamp(minFreq, maxFreq)) / ln10;
  return ((val - minF) / (maxF - minF)) * width;
}

double _xToFreq(double x, double width) {
  final minF = log(minFreq) / ln10;
  final maxF = log(maxFreq) / ln10;
  final val = (x / width) * (maxF - minF) + minF;
  return pow(10, val).toDouble();
}

double _gainToY(double gain, double height) {
  // Y is inverted (0 at top, height at bottom)
  final normalized = (gain - minGain) / (maxGain - minGain);
  return height - (normalized * height);
}

double _yToGain(double y, double height) {
  final normalized = 1.0 - (y / height).clamp(0.0, 1.0);
  return (normalized * (maxGain - minGain)) + minGain;
}

/// Data model for an EQ Band
class EqBand {
  bool active;
  int filterType;
  double freq;
  double gain;
  double q;
  int order; // 0=12dB/oct, 1=24dB, 2=36dB, 3=48dB

  EqBand({
    required this.active,
    required this.filterType,
    required this.freq,
    required this.gain,
    required this.q,
    this.order = 0,
  });
}

class KarbeatParametricEq extends AbstractPluginScreen {
  const KarbeatParametricEq({
    super.key,
    required super.target,
  });

  @override
  KarbeatParametricEqState createState() => KarbeatParametricEqState();
}

class KarbeatParametricEqState extends AbstractPluginScreenState<KarbeatParametricEq> {
  // EQ-specific state
  double masterGain = 0.0;
  late List<EqBand> bands;
  int? _draggingNodeIndex;

  // Backend-computed response curve (Zero-Copy lock-free buffers)
  Float32List? _magnitudeBuffer;
  Float32List? _spectrumBuffer;

  final List<Color> _bandColors = [
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.yellowAccent,
    Colors.greenAccent,
    Colors.lightBlueAccent,
    Colors.cyanAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
  ];

  @override
  String get pluginName => 'Parametric EQ';

  // 1. Tell the base class we want the 'telemetry' blob packed by Rust
  @override
  List<String> getRequestedZeroCopyBuffers() => ['telemetry'];

  @override
  void initState() {
    super.initState();
    _initBandsFromParameters();
  }

  // 2. The base class's 60 FPS Ticker automatically feeds us the lock-free data
  @override
  void onZeroCopyBuffersReceived(Map<String, ZeroCopyHandle> buffers) {
    final telemetryBuf = buffers['telemetry'];
    if (telemetryBuf == null) return;

    // FRB maps Rust's `ZeroCopyBuffer::Float32(Arc<[f32]>)` to this Dart subclass
    switch (telemetryBuf.dataType()) {

      case BufferDataTypeDto.float32:
        final int length = telemetryBuf.lengthElements();
        
        // Ensure we have at least the RIFF-style header
        if (length < 2) return;

        // Cast the raw integer address into a C-style Float pointer
        final ptr = ffi.Pointer<ffi.Float>.fromAddress(telemetryBuf.memoryAddress());

        // Create a zero-cost Dart view directly over the Rust memory space
        // This does NOT copy the array; it just creates a viewing window!
        final flatData = ptr.asTypedList(length);

        // Parse the header
        final int spectrumLen = flatData[0].toInt();
        final int magnitudeLen = flatData[1].toInt();

        final int spectrumStart = 2;
        final int magnitudeStart = spectrumStart + spectrumLen;

        // Safety bounds check
        if (flatData.length < magnitudeStart + magnitudeLen) return;

        setState(() {
          // ZERO-COST SPLIT: SublistView creates smaller windows into the main window
          _spectrumBuffer = Float32List.sublistView(flatData, spectrumStart, spectrumStart + spectrumLen);
          _magnitudeBuffer = Float32List.sublistView(flatData, magnitudeStart, magnitudeStart + magnitudeLen);
        });
        break;
      default:
    }
  }

  @override
  void onParametersUpdated() {
    super.onParametersUpdated();
    _applyParametersToState();
  }

  void _initBandsFromParameters() {
    int maxBandIndex = -1;
    for (final p in parameters) {
      final match = RegExp(r'band(\d+)/').firstMatch(p.path);
      if (match != null) {
        final idx = int.parse(match.group(1)!);
        if (idx > maxBandIndex) maxBandIndex = idx;
      }
    }

    final numBands = maxBandIndex >= 0 ? maxBandIndex + 1 : 8;

    bands = List.generate(
      numBands,
      (i) => EqBand(
        active: true,
        filterType: 0,
        freq: 1000.0,
        gain: 0.0,
        q: 0.707,
      ),
    );

    _applyParametersToState();
  }

  void _applyParametersToState() {
    for (final p in parameters) {
      if (p.path == 'base_gain') {
        masterGain = p.value;
        continue;
      }

      final match = RegExp(r'band(\d+)/(.+)').firstMatch(p.path);
      if (match != null) {
        final bandIndex = int.parse(match.group(1)!);

        if (bandIndex >= 0 && bandIndex < bands.length) {
          final band = bands[bandIndex];
          final paramName = match.group(2)!;

          switch (paramName) {
            case 'active':
              band.active = p.value > 0.5;
              break;
            case 'type':
              band.filterType = p.value.toInt();
              break;
            case 'freq':
              band.freq = p.value;
              break;
            case 'q':
              band.q = p.value;
              break;
            case 'gain':
              band.gain = p.value;
              break;
            case 'slope':
              band.order = p.value.toInt();
              break;
          }
        }
      }
    }
  }

  // ==== Backend Communication ====

  void _updateMasterGain(double value) {
    setState(() => masterGain = value);
    // Base class handles the FFI push natively
    setParameter(parameters.firstWhere((p) => p.path == 'base_gain').id, value);
  }

  void _updateBandParam(int bandIdx, int paramType, double value) {
    String suffix = "";

    setState(() {
      final band = bands[bandIdx];
      switch (paramType) {
        case 0:
          band.freq = value;
          suffix = "freq";
          break;
        case 1:
          band.gain = value;
          suffix = "gain";
          break;
        case 2:
          band.q = value;
          suffix = "q";
          break;
        case 3:
          band.active = value > 0.5;
          suffix = "active";
          break;
        case 4:
          band.filterType = value.toInt();
          suffix = "type";
          break;
        case 5:
          band.order = value.toInt();
          suffix = "slope";
          break;
      }
    });

    final path = "band$bandIdx/$suffix";
    setParameter(parameters.firstWhere((p) => p.path == path).id, value);
  }

  // === Graph Interaction ===

  void _onGraphPanStart(DragStartDetails details, BoxConstraints constraints) {
    final localPos = details.localPosition;
    double minDistance = double.infinity;
    int? closestIndex;

    for (int i = 0; i < bands.length; i++) {
      if (!bands[i].active) continue;

      final nx = _freqToX(bands[i].freq, constraints.maxWidth);
      final ny = _gainToY(bands[i].gain, constraints.maxHeight);

      final dist = sqrt(pow(nx - localPos.dx, 2) + pow(ny - localPos.dy, 2));
      if (dist < 30.0 && dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    if (closestIndex != null) {
      setState(() => _draggingNodeIndex = closestIndex);
      // Optional: signal beginParameterEdit for frequency and gain here if desired
    }
  }

  void _onGraphPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_draggingNodeIndex == null) return;

    final localPos = details.localPosition;
    final newFreq = _xToFreq(localPos.dx, constraints.maxWidth);
    final newGain = _yToGain(localPos.dy, constraints.maxHeight);

    _updateBandParam(_draggingNodeIndex!, 0, newFreq.clamp(minFreq, maxFreq));
    _updateBandParam(_draggingNodeIndex!, 1, newGain.clamp(minGain, maxGain));
  }

  void _onGraphPanEnd(DragEndDetails details) {
    // Optional: signal endParameterEdit here
    setState(() => _draggingNodeIndex = null);
  }

  @override
  Widget buildPluginBody(BuildContext context) {
    return Container(
      color: Colors.grey.shade900,
      child: Column(
        children: [
          // TOP: Response Curve
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanStart: (d) => _onGraphPanStart(d, constraints),
                      onPanUpdate: (d) => _onGraphPanUpdate(d, constraints),
                      onPanEnd: _onGraphPanEnd,
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _EqResponsePainter(
                          bands: bands,
                          bandColors: _bandColors,
                          activeNodeIndex: _draggingNodeIndex,
                          magnitudeBuffer: _magnitudeBuffer,
                          spectrumBuffer: _spectrumBuffer,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // BOTTOM: Controls
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMasterStrip(),
                  Container(
                    width: 1,
                    color: Colors.grey.shade800,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          bands.length,
                          (index) => _buildBandStrip(index),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandStrip(int i) {
    final band = bands[i];
    final color = _bandColors[i % _bandColors.length];

    plugin_api.UiPluginParameter? typeParam;
    plugin_api.UiPluginParameter? slopeParam;
    for (final p in parameters) {
      if (p.path == 'band$i/type') typeParam = p;
      if (p.path == 'band$i/slope') slopeParam = p;
    }

    final filterChoices = typeParam?.choices ?? [];
    final slopeChoices = slopeParam?.choices ?? [];

    return Container(
      width: 120, 
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: band.active ? color.withAlpha(100) : Colors.transparent,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Band Header + Active Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      "B${i + 1}",
                      style: TextStyle(
                        color: band.active ? Colors.white70 : Colors.white30,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 32,
                  height: 20,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Switch(
                      value: band.active,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeThumbColor: color,
                      onChanged: (val) =>
                          _updateBandParam(i, 3, val ? 1.0 : 0.0),
                    ),
                  ),
                ),
              ],
            ),

            // Type Dropdown
            SizedBox(
              height: 28,
              child: PopupMenuButton<int>(
                initialValue: band.filterType,
                padding: EdgeInsets.zero,
                color: Colors.grey.shade800,
                onSelected: (val) => _updateBandParam(i, 4, val.toDouble()),
                itemBuilder: (context) => List.generate(
                  filterChoices.length,
                  (idx) => PopupMenuItem<int>(
                    value: idx,
                    height: 32,
                    child: Text(
                      filterChoices[idx],
                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        filterChoices.isNotEmpty && band.filterType < filterChoices.length
                            ? filterChoices[band.filterType]
                            : "",
                        style: const TextStyle(color: Colors.white54, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white54),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 2),

            // Parameter controls
            _buildParamControl(
              "Freq",
              band.freq,
              "band$i/freq",
              (v) => _updateBandParam(i, 0, v),
              suffix: "Hz",
            ),
            _buildParamControl(
              "Gain",
              band.gain,
              "band$i/gain",
              (v) => _updateBandParam(i, 1, v),
              suffix: "dB",
            ),
            _buildParamControl(
              "Q",
              band.q,
              "band$i/q",
              (v) => _updateBandParam(i, 2, v),
              suffix: "",
            ),

            // Slope dropdown
            const SizedBox(height: 4),
            SizedBox(
              height: 28,
              child: PopupMenuButton<int>(
                initialValue: band.order,
                padding: EdgeInsets.zero,
                color: Colors.grey.shade800,
                onSelected: (val) => _updateBandParam(i, 5, val.toDouble()),
                itemBuilder: (context) => List.generate(
                  slopeChoices.length,
                  (idx) => PopupMenuItem<int>(
                    value: idx,
                    height: 32,
                    child: Text(
                      slopeChoices[idx],
                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        slopeChoices.isNotEmpty && band.order < slopeChoices.length
                            ? slopeChoices[band.order]
                            : "",
                        style: const TextStyle(color: Colors.white54, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterStrip() {
    plugin_api.UiPluginParameter? p;
    for (final param in parameters) {
      if (param.path == 'base_gain') {
        p = param;
        break;
      }
    }

    final pMin = p?.min ?? minGain;
    final pMax = p?.max ?? maxGain;
    final pDef = p?.defaultValue ?? 0.0;
    final pStep = p?.step ?? 0.1;
    final pId = p?.id ?? -1;
    final pValue = p?.value ?? 0.0;

    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "MASTER",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: DawFloatParam(
                paramId: pId,
                name: 'Gain',
                value: pValue,
                min: pMin,
                max: pMax,
                defaultValue: pDef,
                step: pStep,
                suffix: "dB",
                onChanged: _updateMasterGain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${masterGain.toStringAsFixed(1)} dB",
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamControl(
    String label,
    double val,
    String paramPath,
    ValueChanged<double> onChanged, {
    String suffix = "",
  }) {
    plugin_api.UiPluginParameter? p;
    for (final param in parameters) {
      if (param.path == paramPath) {
        p = param;
        break;
      }
    }

    final pMin = p?.min ?? 0.0;
    final pMax = p?.max ?? 1.0;
    final pDef = p?.defaultValue ?? 0.0;
    final pStep = p?.step ?? 0.1;
    final pId = p?.id ?? -1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: DawFloatParam(
        paramId: pId,
        name: label,
        value: val,
        min: pMin,
        max: pMax,
        defaultValue: pDef,
        step: pStep,
        suffix: suffix,
        onChanged: onChanged,
      ),
    );
  }
}

/// Custom graph painter to render the frequency response curve and interactable nodes
class _EqResponsePainter extends CustomPainter {
  final List<EqBand> bands;
  final List<Color> bandColors;
  final int? activeNodeIndex;
  final Float32List? magnitudeBuffer;
  final Float32List? spectrumBuffer;

  _EqResponsePainter({
    required this.bands,
    required this.bandColors,
    required this.activeNodeIndex,
    required this.magnitudeBuffer,
    required this.spectrumBuffer,
  });

  List<Offset> _bufferToOffsets(
    Float32List buf,
    double w,
    double h,
    double Function(double db, double h) yMapper,
  ) {
    final pts = <Offset>[];
    for (int i = 0; i + 1 < buf.length; i += 2) {
      final freq = buf[i].toDouble();
      final db = buf[i + 1].toDouble();
      if (freq <= 0) continue; 
      pts.add(Offset(_freqToX(freq, w), yMapper(db, h)));
    }
    return pts;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawGrid(canvas, w, h);
    _drawZeroDbLine(canvas, w, h);

    if (spectrumBuffer != null && spectrumBuffer!.isNotEmpty) {
      _drawSpectrum(canvas, w, h);
    }

    if (magnitudeBuffer != null && magnitudeBuffer!.isNotEmpty) {
      _drawMagnitudeCurve(canvas, w, h);
    }

    _drawNodes(canvas, w, h);
  }

  void _drawGrid(Canvas canvas, double w, double h) {
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (final f in [50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0]) {
      final x = _freqToX(f, w);
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);

      tp.text = TextSpan(
        text: f >= 1000 ? '${f ~/ 1000}k' : '${f.toInt()}',
        style: const TextStyle(color: Colors.white30, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas, Offset(x + 2, h - 14));
    }
  }

  void _drawZeroDbLine(Canvas canvas, double w, double h) {
    canvas.drawLine(
      Offset(0, h / 2),
      Offset(w, h / 2),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 1,
    );
  }

  void _drawSpectrum(Canvas canvas, double w, double h) {
    double spectrumY(double db, double height) {
      const floor = -100.0;
      const ceil = 24.0;
      final norm = (db - floor) / (ceil - floor);
      return height - norm.clamp(0.0, 1.0) * height;
    }

    final pts = _bufferToOffsets(spectrumBuffer!, w, h, spectrumY);
    if (pts.isEmpty) return;

    final curvePath = _buildSmoothPath(pts);

    final fillPath = Path.from(curvePath)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withAlpha(120), Colors.white.withAlpha(20)],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      curvePath,
      Paint()
        ..color = Colors.white.withAlpha(150)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  void _drawMagnitudeCurve(Canvas canvas, double w, double h) {
    double magnitudeY(double db, double height) =>
        _gainToY(db.clamp(minGain, maxGain), height);

    final pts = _bufferToOffsets(magnitudeBuffer!, w, h, magnitudeY);
    if (pts.isEmpty) return;

    final curvePath = _buildSmoothPath(pts);

    final fillPath = Path.from(curvePath)
      ..lineTo(w, h / 2)
      ..lineTo(0, h / 2)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = Colors.cyanAccent.withAlpha(20)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      curvePath,
      Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  void _drawNodes(Canvas canvas, double w, double h) {
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < bands.length; i++) {
      if (!bands[i].active) continue;

      final x = _freqToX(bands[i].freq, w);
      final y = _gainToY(bands[i].gain, h);
      final color = bandColors[i];
      final isDragging = activeNodeIndex == i;
      final radius = isDragging ? 8.0 : 6.0;

      canvas.drawLine(
        Offset(x, y),
        Offset(x, h / 2),
        Paint()
          ..color = color.withAlpha(isDragging ? 150 : 50)
          ..strokeWidth = 1,
      );

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      tp.text = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _EqResponsePainter old) =>
      old.magnitudeBuffer != magnitudeBuffer ||
      old.spectrumBuffer != spectrumBuffer ||
      old.activeNodeIndex != activeNodeIndex ||
      old.bands != bands;
}

Path _buildSmoothPath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  if (pts.length == 1) {
    path.addOval(Rect.fromCircle(center: pts[0], radius: 1));
    return path;
  }

  path.moveTo(pts[0].dx, pts[0].dy);

  Offset pAt(int i) {
    if (i < 0) return pts.first;
    if (i >= pts.length) return pts.last;
    return pts[i];
  }

  for (int i = 0; i < pts.length - 1; i++) {
    final p0 = pAt(i - 1);
    final p1 = pAt(i);
    final p2 = pAt(i + 1);
    final p3 = pAt(i + 2);

    final c1 = Offset(
      p1.dx + (p2.dx - p0.dx) / 6.0,
      p1.dy + (p2.dy - p0.dy) / 6.0,
    );
    final c2 = Offset(
      p2.dx - (p3.dx - p1.dx) / 6.0,
      p2.dy - (p3.dy - p1.dy) / 6.0,
    );

    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }

  return path;
}