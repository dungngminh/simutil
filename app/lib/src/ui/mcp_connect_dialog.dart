import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';

/// How one agent connects to the MCP server at a URL.
class _AgentGuide {
  const _AgentGuide(this.name, this.where, this.snippet);

  final String name;

  /// Where the snippet goes: a terminal or a config file.
  final String where;
  final String Function(Uri url) snippet;
}

final _guides = [
  _AgentGuide(
    'Claude Code',
    'Run in a terminal',
    (url) => 'claude mcp add --transport http simutil $url',
  ),
  _AgentGuide(
    'Codex',
    'Add to ~/.codex/config.toml',
    (url) => '[mcp_servers.simutil]\nurl = "$url"',
  ),
  _AgentGuide(
    'Cursor',
    'Add to ~/.cursor/mcp.json',
    (url) => _json({
      'mcpServers': {
        'simutil': {'url': '$url'},
      },
    }),
  ),
  _AgentGuide(
    'Gemini CLI',
    'Add to ~/.gemini/settings.json',
    (url) => _json({
      'mcpServers': {
        'simutil': {'httpUrl': '$url'},
      },
    }),
  ),
  _AgentGuide(
    'VS Code',
    'Add to .vscode/mcp.json',
    (url) => _json({
      'servers': {
        'simutil': {'type': 'http', 'url': '$url'},
      },
    }),
  ),
];

String _json(Object value) => const JsonEncoder.withIndent('  ').convert(value);

/// Strings, keys, TOML tables, CLI flags and URLs in the snippet.
final _tokens = RegExp(
  r'("(?:[^"\\]|\\.)*")(\s*:)?|^(\[[^\]]+\])|^([A-Za-z_]+)(?=\s*=)|'
  r'(--?[A-Za-z][\w-]*)|(https?://\S+)',
  multiLine: true,
);

/// [code] as spans colored by [_tokens]; everything else in [base].
TextSpan _highlight(String code, TextStyle base, SimuTokens t) {
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in _tokens.allMatches(code)) {
    spans.add(TextSpan(text: code.substring(last, m.start)));
    final color = switch (m) {
      _ when m[1] != null && m[2] != null => t.apple,
      _ when m[1] != null => t.success,
      _ when m[3] != null => t.warning,
      _ when m[4] != null => t.apple,
      _ when m[5] != null => t.textMuted,
      _ => t.success,
    };
    // A key's colon stays in the base color.
    final token = m[1] ?? m[0]!;
    spans.add(
      TextSpan(
        text: token,
        style: TextStyle(color: color),
      ),
    );
    if (m[1] != null && m[2] != null) spans.add(TextSpan(text: m[2]));
    last = m.end;
  }
  spans.add(TextSpan(text: code.substring(last)));
  return TextSpan(style: base, children: spans);
}

Future<void> showMcpConnectDialog(
  BuildContext context, {
  required Uri url,
  required bool running,
}) => showDialog<void>(
  context: context,
  builder: (_) => McpConnectDialog(url: url, running: running),
);

/// Lists agents and the snippet that connects each to SimUtil's MCP server.
class McpConnectDialog extends StatefulWidget {
  const McpConnectDialog({super.key, required this.url, required this.running});

  final Uri url;
  final bool running;

  @override
  State<McpConnectDialog> createState() => _McpConnectDialogState();
}

class _McpConnectDialogState extends State<McpConnectDialog> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    final guide = _guides[_selected];
    return Dialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimuTokens.radiusLarge),
        side: BorderSide(color: t.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 12),
              _ServerStatus(url: widget.url, running: widget.running),
              const SizedBox(height: 16),
              _AgentTabs(
                selected: _selected,
                onSelect: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: 12),
              Text(guide.where, style: t.caption),
              const SizedBox(height: 6),
              _Snippet(text: guide.snippet(widget.url)),
              const SizedBox(height: 12),
              Text(
                'Restart the agent session after adding the server so it '
                'loads the SimUtil tools.',
                style: t.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text('Connect an agent', style: SimuTokens.of(context).title),
      ),
      SimuIconButton(icon: LucideIcons.x, tooltip: 'Close', onPressed: onClose),
    ],
  );
}

/// Server URL with a dot telling whether it is listening.
class _ServerStatus extends StatelessWidget {
  const _ServerStatus({required this.url, required this.running});

  final Uri url;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Row(
      children: [
        SimuStatusDot(color: running ? t.success : t.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            running
                ? 'MCP server running at $url'
                : 'MCP server not running (port ${url.port} is taken?)',
            style: t.body,
          ),
        ),
      ],
    );
  }
}

class _AgentTabs extends StatelessWidget {
  const _AgentTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (var i = 0; i < _guides.length; i++)
        SimuButton(
          label: _guides[i].name,
          primary: i == selected,
          onPressed: () => onSelect(i),
        ),
    ],
  );
}

/// Monospace block with a copy button.
class _Snippet extends StatelessWidget {
  const _Snippet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText.rich(
              _highlight(text, t.mono.copyWith(color: t.text, height: 1.5), t),
            ),
          ),
          SimuIconButton(
            icon: LucideIcons.copy,
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              showNotice(
                context,
                'Copied to clipboard',
                tone: NoticeTone.success,
              );
            },
          ),
        ],
      ),
    );
  }
}
