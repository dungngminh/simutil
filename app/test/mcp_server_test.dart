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

  Future<(int, Object?)> post(
    Object body, {
    String? origin,
    Map<String, String> headers = const {},
  }) async {
    final request = await client.postUrl(server.url);
    if (origin != null) request.headers.set('origin', origin);
    headers.forEach(request.headers.set);
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

  group('2026-07-28 (stateless)', () {
    const version = McpServer.latestVersion;
    Map<String, Object?> request(
      Object id,
      String method, [
      Map<String, Object?> params = const {},
      String metaVersion = version,
    ]) => {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': {
        ...params,
        '_meta': {
          'io.modelcontextprotocol/protocolVersion': metaVersion,
          'io.modelcontextprotocol/clientInfo': {
            'name': 'test',
            'version': '1',
          },
          'io.modelcontextprotocol/clientCapabilities': <String, Object?>{},
        },
      },
    };
    Map<String, String> headersFor(String method, {String? name}) => {
      'mcp-protocol-version': version,
      'mcp-method': method,
      'mcp-name': ?name,
    };

    test('server/discover advertises versions and identity', () async {
      final (status, reply) = await post(
        request(1, 'server/discover'),
        headers: headersFor('server/discover'),
      );
      expect(status, HttpStatus.ok);
      final result = (reply! as Map)['result'] as Map;
      expect(result['resultType'], 'complete');
      expect(result['supportedVersions'], contains(version));
      expect(
        (result['_meta'] as Map)['io.modelcontextprotocol/serverInfo'],
        isNotNull,
      );
    });

    test('lists with cache hints and calls tools', () async {
      final (_, list) = await post(
        request(1, 'tools/list'),
        headers: headersFor('tools/list'),
      );
      final listed = (list! as Map)['result'] as Map;
      expect(listed['tools'], hasLength(1));
      expect(listed['ttlMs'], isA<int>());
      expect(listed['cacheScope'], 'public');

      final (status, call) = await post(
        request(2, 'tools/call', {
          'name': 'echo',
          'arguments': {'v': 'hi'},
        }),
        // Base64 sentinel form of "echo".
        headers: headersFor('tools/call', name: '=?base64?ZWNobw==?='),
      );
      expect(status, HttpStatus.ok);
      expect(((call! as Map)['result'] as Map)['resultType'], 'complete');
      expect(jsonEncode(call), contains('"text":"hi"'));
    });

    test('rejects unsupported versions with the supported list', () async {
      final (status, reply) = await post(
        request(1, 'tools/list', const {}, '1900-01-01'),
        headers: {
          ...headersFor('tools/list'),
          'mcp-protocol-version': '1900-01-01',
        },
      );
      expect(status, HttpStatus.badRequest);
      final error = (reply! as Map)['error'] as Map;
      expect(error['code'], -32022);
      expect((error['data'] as Map)['supported'], contains(version));
    });

    test('rejects missing or mismatched headers', () async {
      final (missing, reply) = await post(request(1, 'tools/list'));
      expect(missing, HttpStatus.badRequest);
      expect(((reply! as Map)['error'] as Map)['code'], -32020);

      final (mismatch, _) = await post(
        request(2, 'tools/call', {'name': 'echo'}),
        headers: headersFor('tools/call', name: 'other'),
      );
      expect(mismatch, HttpStatus.badRequest);
    });

    test('unknown methods (incl. removed ping) are 404', () async {
      final (status, reply) = await post(
        request(1, 'ping'),
        headers: headersFor('ping'),
      );
      expect(status, HttpStatus.notFound);
      expect(((reply! as Map)['error'] as Map)['code'], -32601);
    });
  });

  test('legacy initialize negotiates a legacy version', () async {
    Future<Object?> init(String version) async {
      final (_, reply) = await post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': version},
      });
      return ((reply! as Map)['result'] as Map)['protocolVersion'];
    }

    expect(await init('2025-06-18'), '2025-06-18');
    expect(await init('2026-07-28'), McpServer.legacyVersions.first);
  });
}
