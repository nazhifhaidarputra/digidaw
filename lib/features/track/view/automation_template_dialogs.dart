import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/features/track/models/automation_curve_template.dart';
import 'package:karbeat/features/track/services/automation_template_service.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';

/// Asks for a template name. Resolves with the trimmed name, or null when
/// cancelled or left empty.
Future<String?> showAutomationTemplateNameDialog({
  required BuildContext context,
  required String title,
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TemplateNameDialog(title: title, initialName: initialName),
  );
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _controller.text.trim().isEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 280,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Template name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isEmpty ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Opens the template library to rename or delete saved curves.
Future<void> showAutomationTemplateManager(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _TemplateManagerDialog(),
  );
}

class _TemplateManagerDialog extends ConsumerWidget {
  const _TemplateManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final templates = ref.watch(automationTemplatesProvider).value;
    final library = ref.read(automationTemplatesProvider.notifier);

    return AlertDialog(
      title: const Text('Curve templates'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 380,
        child: templates == null || templates.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No templates yet. Pick the Select tool, drag a range on an '
                  'automation lane, then right-click it and choose '
                  '"Save as template".',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final template in templates)
                    ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 64,
                        height: 28,
                        child: AutomationTemplatePreview(template: template),
                      ),
                      title: Text(template.name),
                      subtitle: Text(
                        '${template.points.length} points, '
                        '${(template.lengthTicks / 960).toStringAsFixed(2)} beats',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rename',
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () async {
                              final name =
                                  await showAutomationTemplateNameDialog(
                                    context: context,
                                    title: 'Rename template',
                                    initialName: template.name,
                                  );
                              if (name != null) {
                                await library.rename(template.id, name);
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: colors.error,
                            ),
                            onPressed: () => library.remove(template.id),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Small drawing of a template's curve, sampled by the audio engine's code.
class AutomationTemplatePreview extends ConsumerWidget {
  const AutomationTemplatePreview({super.key, required this.template});

  final AutomationCurveTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomPaint(
      painter: _TemplatePreviewPainter(
        template: template,
        sampler: ref.watch(curveSamplerProvider),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _TemplatePreviewPainter extends CustomPainter {
  _TemplatePreviewPainter({
    required this.template,
    required this.sampler,
    required this.color,
  });

  final AutomationCurveTemplate template;
  final CurveSampler sampler;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final count = size.width.ceil().clamp(2, 256);
    final samples = sampler.sampleLane(
      template.points.unlockView,
      startTick: 0,
      endTick: template.lengthTicks.toDouble(),
      count: count,
    );
    if (samples.isEmpty) return;

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = size.width * i / (count - 1);
      final y = size.height - samples[i].clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TemplatePreviewPainter oldDelegate) =>
      oldDelegate.template != template ||
      oldDelegate.sampler != sampler ||
      oldDelegate.color != color;
}
