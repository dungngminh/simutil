import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_type.dart';

class DeviceListComponent extends StatefulComponent {
  const DeviceListComponent({
    super.key,
    required this.devices,
    this.focused = false,
    this.selectedIndex = 0,
    this.scrollBufferItems = 2,
    this.onSelectionChanged,
    this.onDeviceLaunchRequested,
    this.onDeviceShowOptions,
    this.onDeviceShutdownRequested,
    this.isLoading = false,
    this.loadingMessage = 'Loading devices...',
    this.emptyMessage = 'No devices found',
  });

  final List<Device> devices;
  final bool focused;
  final int selectedIndex;
  final int scrollBufferItems;
  final void Function(int)? onSelectionChanged;
  final void Function(Device)? onDeviceLaunchRequested;
  final void Function(Device)? onDeviceShowOptions;
  final void Function(Device)? onDeviceShutdownRequested;
  final bool isLoading;
  final String loadingMessage;
  final String emptyMessage;

  @override
  State<DeviceListComponent> createState() => _DeviceListComponentState();
}

class _DeviceListComponentState extends State<DeviceListComponent> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);

    if (component.isLoading) {
      return Center(
        child: Text(
          component.loadingMessage,
          style: st.dimmed,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (component.devices.isEmpty) {
      return Center(
        child: Text(
          component.emptyMessage,
          style: st.dimmed,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: ListView.builder(
        controller: _scrollController,
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
    switch (event.logicalKey) {
      case LogicalKey.arrowUp:
        _handleArrowUp();
        return true;
      case LogicalKey.arrowDown:
        _handleArrowDown();
        return true;
      case LogicalKey.enter:
        _handleEnter();
        return true;
      case LogicalKey.space:
        _handleSpace();
        return true;
      case LogicalKey.keyT:
        _handleShutdown();
        return true;
      default:
        return false;
    }
  }

  void _handleArrowUp() {
    final newIndex = (component.selectedIndex - 1).clamp(
      0,
      component.devices.length - 1,
    );
    component.onSelectionChanged?.call(newIndex);
    final scrollTarget = (newIndex - component.scrollBufferItems).clamp(
      0,
      component.devices.length - 1,
    );
    _scrollController.ensureIndexVisible(index: scrollTarget);
  }

  void _handleArrowDown() {
    final newIndex = (component.selectedIndex + 1).clamp(
      0,
      component.devices.length - 1,
    );
    component.onSelectionChanged?.call(newIndex);
    final scrollTarget = (newIndex + component.scrollBufferItems).clamp(
      0,
      component.devices.length - 1,
    );
    _scrollController.ensureIndexVisible(index: scrollTarget);
  }

  void _handleEnter() {
    if (component.selectedIndex < component.devices.length) {
      component.onDeviceShowOptions?.call(
        component.devices[component.selectedIndex],
      );
    }
  }

  void _handleSpace() {
    if (component.selectedIndex < component.devices.length) {
      component.onDeviceLaunchRequested?.call(
        component.devices[component.selectedIndex],
      );
    }
  }

  void _handleShutdown() {
    if (component.selectedIndex < component.devices.length) {
      component.onDeviceShutdownRequested?.call(
        component.devices[component.selectedIndex],
      );
    }
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
        Text('${device.platform} ', style: st.muted),
        if (device.type == DeviceType.simulator)
          Text('${device.state.label} ', style: stateStyle)
        else
          Text('Physical', style: st.muted),
      ],
    );
  }
}
