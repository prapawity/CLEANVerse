// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';
import 'package:cleanverse/src/app/ui.dart';
import 'package:cleanverse/src/features/developer/tool_commands.dart';

/// Package-manager caches cleaned through each tool's own command, after a
/// confirmation that shows the exact command.
class ToolCommandsPanel extends StatefulWidget {
  const ToolCommandsPanel({
    super.key,
    required this.enabled,
    required this.windows,
    this.tools,
  });
  final bool enabled;
  final bool windows;
  final ToolCommands? tools;

  @override
  State<ToolCommandsPanel> createState() => _ToolCommandsPanelState();
}

class _ToolCommandsPanelState extends State<ToolCommandsPanel> {
  late final ToolCommands tools = widget.tools ?? ToolCommands();
  Map<ToolCommand, ToolStatus>? statuses;
  final Map<ToolCommand, String> results = {};
  ToolCommand? running;

  List<ToolCommand> get _tools => [
    for (final t in ToolCommand.values)
      if (t.supportedOn(windows: widget.windows)) t,
  ];

  Future<void> _check() async {
    setState(() => running = _tools.first);
    final found = <ToolCommand, ToolStatus>{};
    for (final t in _tools) {
      found[t] = await tools.status(t);
    }
    if (!mounted) return;
    setState(() {
      statuses = found;
      running = null;
    });
  }

  Future<void> _clean(ToolCommand tool) async {
    String? preview;
    if (tool.preview != null) {
      setState(() => running = tool);
      final r = await tools.preview(tool);
      if (!mounted) return;
      setState(() => running = null);
      preview = r.output;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clean ${tool.label}?'),
        content: SingleChildScrollView(
          child: Text(
            '${tool.description}\n\nRuns: ${tool.cleanCommand}\n'
            '${preview != null ? '\nDry run:\n$preview\n' : ''}'
            '\n${tool.label} decides what to remove. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clean'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => running = tool);
    final r = await tools.clean(tool);
    if (!mounted) return;
    setState(() {
      running = null;
      results[tool] = r.output;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && running == null;
    final current = statuses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CvSpace.lg),
        const Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 18, color: CvColors.violet),
            SizedBox(width: CvSpace.sm),
            Text(
              'Package manager caches',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const Text(
          'Cleaned by each tool\'s own command. Installed packages and projects are not touched.',
          style: TextStyle(color: CvColors.muted, fontSize: 12),
        ),
        const SizedBox(height: CvSpace.sm),
        if (current == null)
          OutlinedButton.icon(
            onPressed: enabled ? _check : null,
            icon: const Icon(Icons.search_rounded),
            label: Text(running == null ? 'Check tools' : 'Checking…'),
          )
        else
          for (final t in _tools)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.label),
                            Text(
                              t.description,
                              style: const TextStyle(
                                color: CvColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: CvSpace.sm),
                      if (running == t)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (current[t] == ToolStatus.available)
                        OutlinedButton(
                          onPressed: enabled ? () => _clean(t) : null,
                          child: Text('Clean ${t.label}'),
                        )
                      else
                        StatusChip(
                          current[t] == ToolStatus.failed
                              ? 'Did not respond'
                              : 'Not installed',
                          color: CvColors.muted,
                        ),
                    ],
                  ),
                  if (results[t] != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        results[t]!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
