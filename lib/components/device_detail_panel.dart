import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/models/device.dart';

class DeviceDetailPanel extends StatelessComponent {

  const DeviceDetailPanel({super.key, this.device, this.focused = false});
  final Device? device;
  final bool focused;

  @override
  Component build(BuildContext context) {
    final st = SimutilTheme.of(context);

    return Container(
      decoration: focused
          ? st.focusedPanel('Details')
          : st.unfocusedPanel('Details'),
      child: Padding(
        padding: EdgeInsets.all(1),
        child: device != null ? _buildInfo(st, device!) : _buildEmpty(st),
      ),
    );
  }

  Component _buildInfo(SimutilTheme st, Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(' Device Info', style: st.sectionHeader),
        Divider(),
        _row(st, 'Name', device.name),
        _row(st, 'ID', device.id),
        _row(st, 'Platform', device.platform),
        _row(st, 'Type', device.os.name),
        _row(st, 'State', device.state.label),
        Divider(),
        Text(' ⏎ Launch  R Refresh  S Settings', style: st.dimmed),
      ],
    );
  }

  Component _buildEmpty(SimutilTheme st) {
    return Center(
      child: Text('Select a device to view details', style: st.muted),
    );
  }

  Component _row(SimutilTheme st, String label, String value) {
    return Row(
      children: [
        SizedBox(width: 12, child: Text(' $label', style: st.label)),
        Text(': $value', style: st.body),
      ],
    );
  }
}
