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
class McpServer {
  McpServer({required this.tools, this.port = 8765});

  final List<McpTool> tools;
  final int port;

  static const _protocolVersion = '2025-06-18';

  HttpServer? _server;

  Uri get url => Uri.parse('http://127.0.0.1:$port/mcp');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handle);
  }

  Future<void> stop() async => _server?.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    // Loopback is still reachable from web pages; reject foreign origins
    // (DNS rebinding).
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
    final messages = body is List ? body : [body];
    final replies = [
      for (final message in messages)
        ?await _dispatch(message),
    ];
    if (replies.isEmpty) {
      response.statusCode = HttpStatus.accepted;
      return response.close();
    }
    return _json(response, body is List ? replies : replies.single);
  }

  /// Returns null for notifications.
  Future<Map<String, Object?>?> _dispatch(Object? message) async {
    if (message is! Map) return _error(null, -32600, 'Invalid request');
    final id = message['id'];
    final method = message['method'];
    final params = (message['params'] as Map?)?.cast<String, Object?>() ?? {};
    if (id == null) return null;
    switch (method) {
      case 'initialize':
        return _result(id, {
          'protocolVersion': _protocolVersion,
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': {'name': 'simutil', 'version': '0.1.0'},
        });
      case 'ping':
        return _result(id, <String, Object?>{});
      case 'tools/list':
        return _result(id, {
          'tools': [for (final t in tools) t.toJson()],
        });
      case 'tools/call':
        final name = params['name'];
        final tool = tools.where((t) => t.name == name).firstOrNull;
        if (tool == null) return _error(id, -32602, 'Unknown tool $name');
        final args =
            (params['arguments'] as Map?)?.cast<String, Object?>() ?? {};
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
      default:
        return _error(id, -32601, 'Method not found: $method');
    }
  }

  static Map<String, Object?> _result(Object? id, Object result) => {
    'jsonrpc': '2.0',
    'id': id,
    'result': result,
  };

  static Map<String, Object?> _error(Object? id, int code, String message) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };

  Future<void> _json(HttpResponse response, Object body) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    return response.close();
  }
}
