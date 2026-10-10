import 'dart:typed_data';

/// Minimal MPEG-TS muxer for one H.264 video stream.
///
/// Recordings are written as MPEG-TS so a partial file stays playable;
/// Annex-B access units from scrcpy are wrapped in PES packets.
class TsMuxer {
  static const _packetSize = 188;
  static const _pmtPid = 0x1000;
  static const _videoPid = 0x100;

  final _continuity = <int, int>{};

  /// Muxes one access unit; [pts90k] is in 90 kHz ticks. PAT/PMT are
  /// repeated before key frames so the demuxer can (re)sync.
  Uint8List frame(
    Uint8List annexB, {
    required int pts90k,
    required bool keyFrame,
  }) {
    final out = BytesBuilder(copy: false);
    if (keyFrame) {
      out
        ..add(_psi(0, _pat()))
        ..add(_psi(_pmtPid, _pmt()));
    }
    _pes(out, annexB, pts90k);
    return out.takeBytes();
  }

  Uint8List _pat() => _section(0x00, 0x0001, [
    0x00, 0x01, // program number
    0xE0 | (_pmtPid >> 8), _pmtPid & 0xff,
  ]);

  Uint8List _pmt() => _section(0x02, 0x0001, [
    0xE0 | (_videoPid >> 8), _videoPid & 0xff, // PCR PID
    0xF0, 0x00, // program info length
    0x1B, // H.264
    0xE0 | (_videoPid >> 8), _videoPid & 0xff,
    0xF0, 0x00, // ES info length
  ]);

  /// PSI section with header and CRC32.
  Uint8List _section(int tableId, int idExt, List<int> body) {
    final length = 5 + body.length + 4;
    final bytes = <int>[
      tableId,
      0xB0 | (length >> 8), length & 0xff,
      idExt >> 8, idExt & 0xff,
      0xC1, // version 0, current
      0x00, 0x00, // section number, last section number
      ...body,
    ];
    final crc = crc32Mpeg(bytes);
    return Uint8List.fromList([
      ...bytes,
      crc >> 24 & 0xff,
      crc >> 16 & 0xff,
      crc >> 8 & 0xff,
      crc & 0xff,
    ]);
  }

  Uint8List _psi(int pid, Uint8List section) {
    final packet = Uint8List(_packetSize)..fillRange(0, _packetSize, 0xff);
    _header(packet, pid, start: true, adaptation: false);
    packet[4] = 0; // pointer field
    packet.setRange(5, 5 + section.length, section);
    return packet;
  }

  void _pes(BytesBuilder out, Uint8List data, int pts) {
    final pes = BytesBuilder(copy: false)
      ..add([
        0x00, 0x00, 0x01, 0xE0, // start code, video stream
        0x00, 0x00, // length 0 = unbounded (video)
        0x80, 0x80, 0x05, // PTS only
        ..._timestamp(0x20, pts),
      ])
      ..add(data);
    final payload = pes.takeBytes();

    var offset = 0;
    var first = true;
    while (offset < payload.length) {
      final packet = Uint8List(_packetSize);
      final remaining = payload.length - offset;
      // First packet carries the PCR in its adaptation field.
      final adaptationBody = first ? 7 : 0;
      final room = _packetSize - 4 - (first ? 1 + adaptationBody : 0);
      final take = remaining < room ? remaining : room;
      final stuffing = room - take;
      final hasAdaptation = first || stuffing > 0;
      _header(packet, _videoPid, start: first, adaptation: hasAdaptation);

      var i = 4;
      if (hasAdaptation) {
        // Adaptation field length excludes its own length byte.
        final fieldLength = first ? adaptationBody + stuffing : stuffing - 1;
        packet[i++] = fieldLength;
        if (first) {
          packet[i++] = 0x10; // PCR flag
          final pcr = pts;
          packet
            ..[i++] = pcr >> 25 & 0xff
            ..[i++] = pcr >> 17 & 0xff
            ..[i++] = pcr >> 9 & 0xff
            ..[i++] = pcr >> 1 & 0xff
            ..[i++] = (pcr & 1) << 7 | 0x7E
            ..[i++] = 0
            ..fillRange(i, i + stuffing, 0xff);
          i += stuffing;
        } else if (fieldLength > 0) {
          packet[i++] = 0x00; // no flags
          packet.fillRange(i, i + fieldLength - 1, 0xff);
          i += fieldLength - 1;
        }
      }
      packet.setRange(i, i + take, payload, offset);
      out.add(packet);
      offset += take;
      first = false;
    }
  }

  void _header(
    Uint8List p,
    int pid, {
    required bool start,
    required bool adaptation,
  }) {
    final cc = _continuity[pid] = ((_continuity[pid] ?? -1) + 1) & 0x0f;
    p
      ..[0] = 0x47
      ..[1] = (start ? 0x40 : 0) | (pid >> 8 & 0x1f)
      ..[2] = pid & 0xff
      ..[3] = (adaptation ? 0x30 : 0x10) | cc;
  }

  static List<int> _timestamp(int prefix, int ts) => [
    prefix | (ts >> 29 & 0x0E) | 1,
    ts >> 22 & 0xff,
    (ts >> 14 & 0xFE) | 1,
    ts >> 7 & 0xff,
    (ts << 1 & 0xFE) | 1,
  ];
}

/// CRC-32/MPEG-2 used by PSI sections.
int crc32Mpeg(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc ^= b << 24;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x80000000) != 0 ? (crc << 1) ^ 0x04C11DB7 : crc << 1;
      crc &= 0xffffffff;
    }
  }
  return crc;
}
