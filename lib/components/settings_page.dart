import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// Available theme names that map to nocterm TuiThemeData presets.
const availableThemes = [
  'dark',
  'light',
  'nord',
  'dracula',
  'catppuccin',
  'gruvbox',
];

/// Available GPU modes for Android emulators.
const gpuModes = ['auto', 'host', 'swiftshader_indirect', 'off'];

/// A full-screen settings page for editing app preferences.
class SettingsPage extends StatefulComponent {
  final AppSettings initialSettings;
  final SettingsService settingsService;

  const SettingsPage({
    super.key,
    required this.initialSettings,
    required this.settingsService,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;
  int _focusedField = 0;
  String _statusMessage = '';

  static const _fieldCount = 5; // theme, noAudio, wipeData, gpu, noSnapshot

  @override
  void initState() {
    super.initState();
    _settings = component.initialSettings;
  }

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);
    final options = _settings.defaultLaunchOptions;

    return Focusable(
      focused: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: st.focusedPanel('⚙ Settings'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ' Use ↑/↓ to navigate, ←/→ to change, S to save, Esc to go back',
                style: st.dimmed,
              ),
              Divider(),
              _buildField(
                st,
                index: 0,
                label: 'Theme',
                value: _settings.themeName,
              ),
              Divider(),
              Text(' Default Launch Options', style: st.sectionHeader),
              _buildToggleField(
                st,
                index: 1,
                label: 'No Audio',
                value: options.noAudio,
              ),
              _buildToggleField(
                st,
                index: 2,
                label: 'Wipe Data',
                value: options.wipeData,
              ),
              _buildField(st, index: 3, label: 'GPU Mode', value: options.gpu),
              _buildToggleField(
                st,
                index: 4,
                label: 'No Snapshot',
                value: options.noSnapshot,
              ),
              Expanded(child: SizedBox()),
              if (_statusMessage.isNotEmpty)
                Text(
                  ' $_statusMessage',
                  style: _statusMessage.contains('✓')
                      ? st.successStyle
                      : st.warningStyle,
                ),
              Divider(),
              Text(' S Save  Esc Back', style: st.dimmed),
            ],
          ),
        ),
      ),
    );
  }

  Component _buildField(
    SimutilTheme st, {
    required int index,
    required String label,
    required String value,
  }) {
    final isFocused = _focusedField == index;
    return Row(
      children: [
        Text(isFocused ? ' ${SimutilIcons.pointer} ' : '   ', style: st.label),
        SizedBox(
          width: 16,
          child: Text(label, style: isFocused ? st.bold : st.body),
        ),
        Text(
          '${SimutilIcons.cycleLeft} ',
          style: isFocused ? st.body : st.dimmed,
        ),
        Text(
          value,
          style: TextStyle(
            color: st.warning,
            fontWeight: isFocused ? FontWeight.bold : null,
          ),
        ),
        Text(
          ' ${SimutilIcons.cycleRight}',
          style: isFocused ? st.body : st.dimmed,
        ),
      ],
    );
  }

  Component _buildToggleField(
    SimutilTheme st, {
    required int index,
    required String label,
    required bool value,
  }) {
    final isFocused = _focusedField == index;
    return Row(
      children: [
        Text(isFocused ? ' ${SimutilIcons.pointer} ' : '   ', style: st.label),
        SizedBox(
          width: 16,
          child: Text(label, style: isFocused ? st.bold : st.body),
        ),
        Text(
          value ? SimutilIcons.checked : SimutilIcons.unchecked,
          style: TextStyle(
            color: value ? st.success : st.outlineVariant,
            fontWeight: isFocused ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      Navigator.of(context).pop(_settings);
      return true;
    }

    if (event.logicalKey == LogicalKey.keyS) {
      _saveSettings();
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        _focusedField = (_focusedField - 1).clamp(0, _fieldCount - 1);
      });
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        _focusedField = (_focusedField + 1).clamp(0, _fieldCount - 1);
      });
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.arrowRight) {
      _cycleField(event.logicalKey == LogicalKey.arrowRight);
      return true;
    }

    if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _cycleField(true);
      return true;
    }

    return false;
  }

  void _cycleField(bool forward) {
    setState(() {
      _statusMessage = '';
      switch (_focusedField) {
        case 0: // Theme
          final idx = availableThemes.indexOf(_settings.themeName);
          final next = forward
              ? (idx + 1) % availableThemes.length
              : (idx - 1 + availableThemes.length) % availableThemes.length;
          _settings = _settings.copyWith(themeName: availableThemes[next]);
          break;
        case 1:
          _settings = _settings.copyWith(
            defaultLaunchOptions: _settings.defaultLaunchOptions.copyWith(
              noAudio: !_settings.defaultLaunchOptions.noAudio,
            ),
          );
          break;
        case 2:
          _settings = _settings.copyWith(
            defaultLaunchOptions: _settings.defaultLaunchOptions.copyWith(
              wipeData: !_settings.defaultLaunchOptions.wipeData,
            ),
          );
          break;
        case 3: // GPU Mode
          final idx = gpuModes.indexOf(_settings.defaultLaunchOptions.gpu);
          final next = forward
              ? (idx + 1) % gpuModes.length
              : (idx - 1 + gpuModes.length) % gpuModes.length;
          _settings = _settings.copyWith(
            defaultLaunchOptions: _settings.defaultLaunchOptions.copyWith(
              gpu: gpuModes[next],
            ),
          );
          break;
        case 4:
          _settings = _settings.copyWith(
            defaultLaunchOptions: _settings.defaultLaunchOptions.copyWith(
              noSnapshot: !_settings.defaultLaunchOptions.noSnapshot,
            ),
          );
          break;
      }
    });
  }

  Future<void> _saveSettings() async {
    try {
      await component.settingsService.save(_settings);
      setState(() => _statusMessage = '✓ Settings saved');
    } catch (e) {
      setState(() => _statusMessage = '✗ Failed to save: $e');
    }
  }
}
