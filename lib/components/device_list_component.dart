import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';

class DeviceListComponent extends StatefulComponent {
  const DeviceListComponent({
    super.key,
    required this.devices,
    this.focused = false,
    this.selectedIndex = 0,
    this.onSelectionChanged,
    this.onDeviceLaunch,
    this.onDeviceShowOptions,
    this.isLoading = false,
    this.emptyMessage = 'No devices found',
  });

  final List<Device> devices;
  final bool focused;
  final int selectedIndex;
  final ValueChanged<int>? onSelectionChanged;
  final ValueChanged<Device>? onDeviceLaunch;
  final ValueChanged<Device>? onDeviceShowOptions;
  final bool isLoading;
  final String emptyMessage;

  @override
  State<DeviceListComponent> createState() => _DeviceListComponentState();
}

class _DeviceListComponentState extends State<DeviceListComponent> {
  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);

    if (component.isLoading) {
      return Center(child: Text('Loading devices...', style: st.dimmed));
    }

    if (component.devices.isEmpty) {
      return Center(child: Text(component.emptyMessage, style: st.dimmed));
    }

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: ListView.builder(
        itemCount: component.devices.length,
        itemBuilder: (context, index) {
          final device = component.devices[index];
          final isSelected = index == component.selectedIndex;

          return _DeviceRow(
            device: device,
            isSelected: isSelected && component.focused,
          );
        },
      ),
    );
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (component.devices.isEmpty) return false;

    if (event.logicalKey == LogicalKey.arrowUp) {
      final newIndex = (component.selectedIndex - 1).clamp(
        0,
        component.devices.length - 1,
      );
      component.onSelectionChanged?.call(newIndex);
      return true;
    }

    if (event.logicalKey == LogicalKey.arrowDown) {
      final newIndex = (component.selectedIndex + 1).clamp(
        0,
        component.devices.length - 1,
      );
      component.onSelectionChanged?.call(newIndex);
      return true;
    }

    // Enter → launch with default options
    if (event.logicalKey == LogicalKey.enter) {
      if (component.selectedIndex < component.devices.length) {
        component.onDeviceLaunch?.call(
          component.devices[component.selectedIndex],
        );
      }
      return true;
    }

    // Space → show launch options dialog
    if (event.logicalKey == LogicalKey.space) {
      if (component.selectedIndex < component.devices.length) {
        component.onDeviceShowOptions?.call(
          component.devices[component.selectedIndex],
        );
      }
      return true;
    }

    return false;
  }
}

class _DeviceRow extends StatelessComponent {
  const _DeviceRow({required this.device, required this.isSelected});
  final Device device;
  final bool isSelected;

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);
    final stateIcon = device.isRunning ? SimutilIcons.on : SimutilIcons.off;
    final stateStyle = device.isRunning ? st.statusRunning : st.statusStopped;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(' $stateIcon ', style: stateStyle),
        Expanded(
          child: Text(device.name, style: isSelected ? st.selected : st.body),
        ),
        Text(' ${device.platform} ', style: st.muted),
        Text('${device.state.label} ', style: stateStyle),
      ],
    );
  }
}
