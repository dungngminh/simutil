import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One MCP tool: JSON schema for its arguments and the handler.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.handler,
    this.properties = const {},
    this.required = const [],
  });

  final String name;
  final String description;
  final Map<String, Object?> properties;
  final List<String> required;

  /// Returns MCP content items (`{type: text|image, ...}`).
  final Future<List<Map<String, Object?>>> Function(Map<String, Object?> args)
  handler;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': {
      'type': 'object',
      'properties': properties,
      'required': required,
    },
  };
}

/// Minimal MCP server over Streamable HTTP (JSON responses, no SSE) on
/// loopback, so agents can drive the devices this app manages.
///
/// Dual-era: requests carrying `_meta` protocol metadata are served
/// statelessly per [latestVersion] (`server/discover`, header validation,
/// `resultType`); clients that open with `initialize` get the legacy
/// session-less subset of [legacyVersions].
class McpServer {
  McpServer({required this.tools, this.port = 8765});

  final List<McpTool> tools;
  final int port;

  static const latestVersion = '2026-07-28';
  static const legacyVersions = ['2025-11-25', '2025-06-18', '2025-03-26'];
  static const supportedVersions = [latestVersion, ...legacyVersions];

  static const _meta = 'io.modelcontextprotocol/';
  static const _serverInfo = {'name': 'simutil', 'version': '0.1.0'};
  static const _capabilities = {'tools': <String, Object?>{}};

  /// Error codes reserved by the 2026-07-28 spec.
  static const _headerMismatch = -32020;
  static const _unsupportedVersion = -32022;

  HttpServer? _server;

  Uri get url => Uri.parse('http://127.0.0.1:$port/mcp');

  /// False until [start] binds the port (e.g. it is taken).
  bool get running => _server != null;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handle);
  }

  Future<void> stop() async => _server?.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final origin = request.headers.value('origin');
    if (origin != null) {
      final host = Uri.tryParse(origin)?.host;
      if (host != 'localhost' && host != '127.0.0.1') {
        response.statusCode = HttpStatus.forbidden;
        return response.close();
      }
    }
    if (request.uri.path != '/mcp') {
      response.statusCode = HttpStatus.notFound;
      return response.close();
    }
    if (request.method != 'POST') {
      response
        ..statusCode = HttpStatus.methodNotAllowed
        ..headers.set('allow', 'POST');
      return response.close();
    }

    Object? body;
    try {
      body = jsonDecode(await utf8.decodeStream(request));
    } catch (_) {
      return _json(response, _error(null, -32700, 'Parse error'));
    }

    if (body is Map && _requestedVersion(body) != null) {
      final (status, reply) = await _modern(body, request.headers);
      response.statusCode = status;
      if (reply == null) return response.close();
      return _json(response, reply);
    }

    final messages = body is List ? body : [body];
    final replies = [for (final message in messages) ?await _legacy(message)];
    if (replies.isEmpty) {
      response.statusCode = HttpStatus.accepted;
      return response.close();
    }
    return _json(response, body is List ? replies : replies.single);
  }

  static String? _requestedVersion(Map<Object?, Object?> message) {
    final meta = switch (message['params']) {
      final Map<Object?, Object?> params => params['_meta'],
      _ => null,
    };
    return meta is Map ? meta['${_meta}protocolVersion'] as String? : null;
  }

  /// A 2026-07-28 request: (HTTP status, JSON-RPC reply or null for 202).
  Future<(int, Map<String, Object?>?)> _modern(
    Map<Object?, Object?> message,
    HttpHeaders headers,
  ) async {
    final id = message['id'];
    final method = message['method'];
    final params = (message['params'] as Map?)?.cast<String, Object?>() ?? {};
    if (id == null) return (HttpStatus.accepted, null);

    final version = _requestedVersion(message)!;
    if (version != latestVersion) {
      return (
        HttpStatus.badRequest,
        _error(
          id,
          _unsupportedVersion,
          'Unsupported protocol version',
          data: {'supported': supportedVersions, 'requested': version},
        ),
      );
    }
    if (_mismatch(headers, version, method, params) case final why?) {
      return (
        HttpStatus.badRequest,
        _error(id, _headerMismatch, 'Header mismatch: $why'),
      );
    }

    switch (method) {
      case 'server/discover':
        return (
          HttpStatus.ok,
          _complete(id, {
            'supportedVersions': supportedVersions,
            'capabilities': _capabilities,
            'instructions':
                'Controls the Android emulators/devices and iOS simulators '
                'managed by the SimUtil desktop app.',
            'ttlMs': 3600000,
            'cacheScope': 'public',
          }),
        );
      case 'tools/list':
        return (
          HttpStatus.ok,
          _complete(id, {
            'tools': _toolsJson(),
            'ttlMs': 3600000,
            'cacheScope': 'public',
          }),
        );
      case 'tools/call':
        final reply = await _call(id, params);
        return (
          HttpStatus.ok,
          reply.containsKey('error')
              ? reply
              : _complete(id, reply['result']! as Map<String, Object?>),
        );
      default:
        return (
          HttpStatus.notFound,
          _error(id, -32601, 'Method not found: $method'),
        );
    }
  }

  /// Why the mirrored request headers disagree with the body, or null.
  static String? _mismatch(
    HttpHeaders headers,
    String version,
    Object? method,
    Map<String, Object?> params,
  ) {
    final protocol = headers.value('mcp-protocol-version');
    if (protocol != version) {
      return "MCP-Protocol-Version '$protocol' does not match body '$version'";
    }
    final methodHeader = headers.value('mcp-method');
    if (methodHeader != method) {
      return "Mcp-Method '$methodHeader' does not match body '$method'";
    }
    if (method == 'tools/call') {
      final name = _decodeHeader(headers.value('mcp-name'));
      if (name != params['name']) {
        return "Mcp-Name '$name' does not match body '${params['name']}'";
      }
    }
    return null;
  }

  /// Undoes the `=?base64?…?=` sentinel encoding of header values.
  static String? _decodeHeader(String? value) {
    if (value == null ||
        !value.startsWith('=?base64?') ||
        !value.endsWith('?=')) {
      return value;
    }
    try {
      return utf8.decode(base64.decode(value.substring(9, value.length - 2)));
    } on FormatException {
      return null;
    }
  }

  /// Legacy (`initialize`-based) requests; returns null for notifications.
  Future<Map<String, Object?>?> _legacy(Object? message) async {
    if (message is! Map) return _error(null, -32600, 'Invalid request');
    final id = message['id'];
    final method = message['method'];
    final params = (message['params'] as Map?)?.cast<String, Object?>() ?? {};
    if (id == null) return null;
    switch (method) {
      case 'initialize':
        final requested = params['protocolVersion'];
        return _result(id, {
          'protocolVersion': legacyVersions.contains(requested)
              ? requested
              : legacyVersions.first,
          'capabilities': _capabilities,
          'serverInfo': _serverInfo,
        });
      case 'ping':
        return _result(id, <String, Object?>{});
      case 'tools/list':
        return _result(id, {'tools': _toolsJson()});
      case 'tools/call':
        return _call(id, params);
      default:
        return _error(id, -32601, 'Method not found: $method');
    }
  }

  /// Sorted by name so clients can cache the list.
  List<Map<String, Object?>> _toolsJson() => [
    for (final t in [...tools]..sort((a, b) => a.name.compareTo(b.name)))
      t.toJson(),
  ];

  Future<Map<String, Object?>> _call(
    Object? id,
    Map<String, Object?> params,
  ) async {
    final name = params['name'];
    final tool = tools.where((t) => t.name == name).firstOrNull;
    if (tool == null) return _error(id, -32602, 'Unknown tool $name');
    final args = (params['arguments'] as Map?)?.cast<String, Object?>() ?? {};
    try {
      return _result(id, {'content': await tool.handler(args)});
    } catch (e) {
      return _result(id, {
        'content': [
          {'type': 'text', 'text': '$e'},
        ],
        'isError': true,
      });
    }
  }

  /// A 2026-07-28 result: `resultType` plus the server identity.
  static Map<String, Object?> _complete(
    Object? id,
    Map<String, Object?> result,
  ) => _result(id, {
    'resultType': 'complete',
    ...result,
    '_meta': {'${_meta}serverInfo': _serverInfo},
  });

  static Map<String, Object?> _result(Object? id, Object result) => {
    'jsonrpc': '2.0',
    'id': id,
    'result': result,
  };

  static Map<String, Object?> _error(
    Object? id,
    int code,
    String message, {
    Object? data,
  }) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message, 'data': ?data},
  };

  Future<void> _json(HttpResponse response, Object body) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    return response.close();
  }
}
