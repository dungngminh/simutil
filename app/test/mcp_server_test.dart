import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/mcp/mcp_server.dart';

void main() {
  late McpServer server;
  final client = HttpClient();

  setUp(() async {
    server = McpServer(
      port: 18765,
      tools: [
        McpTool(
          name: 'echo',
          description: 'Echo',
          handler: (args) async => [
            {'type': 'text', 'text': '${args['v']}'},
          ],
        ),
      ],
    );
    await server.start();
  });
  tearDown(() => server.stop());

  Future<(int, Object?)> post(Object body, {String? origin}) async {
    final request = await client.postUrl(server.url);
    if (origin != null) request.headers.set('origin', origin);
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('lists and calls tools', () async {
    final (_, list) = await post({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/list',
    });
    expect(((list! as Map)['result'] as Map)['tools'], hasLength(1));

    final (_, call) = await post({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/call',
      'params': {
        'name': 'echo',
        'arguments': {'v': 'hi'},
      },
    });
    expect(jsonEncode(call), contains('"text":"hi"'));
  });

  test('notifications get 202, foreign origins 403', () async {
    final (status, _) = await post({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    expect(status, HttpStatus.accepted);
    final (forbidden, _) = await post({}, origin: 'https://evil.example');
    expect(forbidden, HttpStatus.forbidden);
  });
}
