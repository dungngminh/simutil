import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:simutil_core/simutil_core.dart';

/// Writes [payload] as JSON to stdout for scripts and agents.
void writeJsonStdout(Object? payload) {
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(payload));
}

/// Returns true when `-j` / `--json` is set on [results].
bool jsonOutputRequested(ArgResults results) => results['json'] == true;

/// Column definition for [formatCliTable].
class CliTableColumn {
  /// Creates a table column.
  const CliTableColumn(this.header, {this.minWidth = 4});

  /// Column title.
  final String header;

  /// Minimum width in characters.
  final int minWidth;
}

/// Renders [rows] as a fixed-width table string.
String formatCliTable({
  required List<CliTableColumn> columns,
  required List<List<String>> rows,
}) {
  if (columns.isEmpty) return '';

  final widths = List<int>.generate(columns.length, (index) {
    final column = columns[index];
    var width = column.header.length;
    for (final row in rows) {
      if (index < row.length && row[index].length > width) {
        width = row[index].length;
      }
    }
    return width < column.minWidth ? column.minWidth : width;
  });

  String padCell(String value, int width) => value.padRight(width);

  final buffer = StringBuffer()
    ..writeln(
      columns
          .asMap()
          .entries
          .map((e) => padCell(e.value.header, widths[e.key]))
          .join('  '),
    )
    ..writeln(widths.map((width) => '─' * width).join('  '));
  for (final row in rows) {
    buffer.writeln(
      columns
          .asMap()
          .entries
          .map((e) {
            final value = e.key < row.length ? row[e.key] : '';
            return padCell(value, widths[e.key]);
          })
          .join('  '),
    );
  }
  return buffer.toString().trimRight();
}

/// Maps a [Device] to table row cells.
List<String> deviceTableRow(Device device) => [
  device.id,
  device.name,
  device.os.name,
  device.type.name,
  device.state.label,
  device.platform,
];

/// Standard device list columns.
const deviceListColumns = [
  CliTableColumn('ID', minWidth: 12),
  CliTableColumn('NAME', minWidth: 16),
  CliTableColumn('OS', minWidth: 8),
  CliTableColumn('TYPE', minWidth: 10),
  CliTableColumn('STATE', minWidth: 10),
  CliTableColumn('PLATFORM', minWidth: 10),
];

/// JSON-friendly device maps including [Device.isRunning].
List<Map<String, dynamic>> devicesToJson(List<Device> devices) => devices
    .map((device) => {...device.toJson(), 'running': device.isRunning})
    .toList();
