import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';

class DeviceDetailPanel extends StatelessComponent {
  const DeviceDetailPanel({super.key, this.device, this.focused = false});

  final Device? device;
  final bool focused;

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;

    return Container(
      decoration: focused
          ? st.focusedPanel('Details')
          : st.unfocusedPanel('Details'),
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: device != null ? _buildInfo(st, device!) : _buildEmpty(st),
    );
  }

  Component _buildInfo(SimutilTheme st, Device device) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(st, label: 'Name', value: device.name),
          _row(st, label: 'ID', value: device.id),
          _row(st, label: 'Platform', value: device.platform),
          _row(st, label: 'Type', value: device.os.label),
          _row(st, label: 'State', value: device.state.label),
        ],
      ),
    );
  }

  Component _buildEmpty(SimutilTheme st) {
    return Center(
      child: Text('Select a device to view details', style: st.muted),
    );
  }

  Component _row(
    SimutilTheme st, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        SizedBox(width: 12, child: Text(label, style: st.label)),
        Text(': $value', style: st.body),
      ],
    );
  }
}
