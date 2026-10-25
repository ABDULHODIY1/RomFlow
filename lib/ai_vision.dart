import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'window_photo.dart';

/// Reads a window photo with Claude, using the workshop's own API key.
/// There is no Anthropic SDK for Dart, so this is the Messages API over
/// HTTPS. The photo goes to Anthropic; nothing else leaves the phone.
class AiVision {
  static const model = 'claude-opus-5-5';
  static final endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  static const _system =
      'You read photos of windows and doors for a window workshop in '
      'Uzbekistan. Describe how the frame of the main window in the photo is '
      'divided by its bars (imposts), as it appears in the photo. Answer only '
      'with the JSON the schema asks for.';

  static const _prompt = '''
Describe the frame in this photo.

- layout "columns": vertical bars run from the top of the frame to the bottom and split it into parts side by side (left to right); a part may be split by horizontal bars into cells (top to bottom).
- layout "rows": a horizontal bar runs across the whole width and splits the frame into parts one above the other (top to bottom); a part may be split by vertical bars into cells (left to right).
Pick the one that matches the bars that cross the whole frame.
- share: the part's width (columns) or height (rows) as a fraction of the frame; a cell's share is its fraction of the part. Measure from the photo; shares in one list add up to 1.
- opening of each cell: "fixed" for glass that does not open; a sash hinged on its left edge is "left", on its right edge "right"; "tiltTurn" for a sash with a handle where the hinge side is unclear (the usual uPVC tilt-and-turn sash); "bottom" for a small top sash that tilts in; "top" for one hinged at the top; "slideLeft" / "slideRight" for sliding sashes; "doorLeft" / "doorRight" for a door leaf hinged on that side; "passive" for the fixed-bolt leaf of a double door.
- fill: "panel" for an opaque (sandwich) panel, otherwise "glass".
- shape "arch" when the top of the frame is curved; then, with layout "rows", the first part is the curved top.
- isWindow false if there is no window or door frame in the photo.
- notes: one short sentence in Uzbek (Latin script) about what you saw.''';

  /// The window in [image] (PNG bytes) as a grid. Throws with a message
  /// the workshop can act on.
  static Future<WindowGrid> read(
    Uint8List image, {
    required String apiKey,
    HttpClient? client,
  }) async =>
      _grid(await _ask(body(image), apiKey, client));

  static const _openingSystem =
      'You find window and door openings in photos for a window workshop '
      'in Uzbekistan. Answer only with the JSON the schema asks for.';

  static const _openingPrompt = '''
Find the opening in this photo where a new window or door will be installed: the hole in the wall, or the old window or door frame that will be replaced (take its outer edge). If there are several, take the biggest one nearest the middle of the photo.
- corners: exactly 4 points in this order: top-left, top-right, bottom-right, bottom-left. x is a fraction of the photo's width (0 at the left edge, 1 at the right), y a fraction of its height (0 at the top, 1 at the bottom). Follow the perspective: the corners need not form a rectangle.
- found false if there is no opening in the photo.
- notes: one short sentence in Uzbek (Latin script) about what you saw.''';

  /// The four corners (top-left first, as fractions of the photo) of the
  /// opening a window or door goes into.
  static Future<List<(double, double)>> findOpening(
    Uint8List image, {
    required String apiKey,
    HttpClient? client,
  }) async {
    final answer = await _ask(
      _request(image, _openingSystem, _openingPrompt, openingSchema),
      apiKey,
      client,
    );
    return openingCorners(answer);
  }

  static const openingSchema = {
    'type': 'object',
    'properties': {
      'found': {'type': 'boolean'},
      'corners': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
          },
          'required': ['x', 'y'],
          'additionalProperties': false,
        },
      },
      'notes': {'type': 'string'},
    },
    'required': ['found', 'corners', 'notes'],
    'additionalProperties': false,
  };

  static List<(double, double)> openingCorners(Map answer) {
    final corners = answer['corners'];
    if (answer['found'] == false || corners is! List || corners.length != 4) {
      final notes = answer['notes'];
      throw AiException(
        'Rasmda o‘rin topilmadi${notes is String && notes.isNotEmpty ? ': $notes' : ''}',
      );
    }
    return [
      for (final c in corners)
        (
          ((c as Map)['x'] as num).toDouble().clamp(0.0, 1.0),
          (c['y'] as num).toDouble().clamp(0.0, 1.0),
        ),
    ];
  }

  static Future<Map> _ask(
    Map<String, dynamic> body,
    String apiKey,
    HttpClient? client,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw const AiException('AI kaliti kiritilmagan: Sozlamalar → AI kamera');
    }
    final http = client ?? HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await http.postUrl(endpoint);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('x-api-key', apiKey.trim())
        ..set('anthropic-version', '2026-10-21')
        // On a safety decline the request is retried on Anthropic's
        // recommended fallback model.
        ..set('anthropic-beta', 'server-side-fallback-2026-07-01');
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(
            const Duration(seconds: 150),
          );
      final text = await utf8.decodeStream(response);
      return parseAnswer(response.statusCode, text);
    } on SocketException {
      throw const AiException('Internetga ulanib bo‘lmadi');
    } on HttpException {
      throw const AiException('Internetga ulanib bo‘lmadi');
    } finally {
      if (client == null) http.close(force: true);
    }
  }

  static Map<String, dynamic> body(Uint8List image) =>
      _request(image, _system, _prompt, windowGridSchema);

  static Map<String, dynamic> _request(
    Uint8List image,
    String system,
    String prompt,
    Map schema,
  ) =>
      {
        'model': model,
        'max_tokens': 16000,
        'fallbacks': 'default',
        'system': system,
        'output_config': {
          'effort': 'medium',
          'format': {'type': 'json_schema', 'schema': schema},
        },
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/png',
                  'data': base64Encode(image),
                },
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      };

  /// The grid from a Messages API response, or the reason there is none.
  static WindowGrid parse(int status, String text) =>
      _grid(parseAnswer(status, text));

  static WindowGrid _grid(Map answer) {
    if (answer['isWindow'] == false) {
      throw AiException(
        'Rasmda rom topilmadi${answer['notes'] is String && (answer['notes'] as String).isNotEmpty ? ': ${answer['notes']}' : ''}',
      );
    }
    return WindowGrid.fromJson(answer);
  }

  /// The JSON answer in a Messages API response, or the reason there is
  /// none.
  static Map parseAnswer(int status, String text) {
    if (status == 401 || status == 403) {
      throw const AiException('AI kaliti noto‘g‘ri yoki ruxsati yo‘q');
    }
    if (status == 429) {
      throw const AiException(
        'So‘rovlar ko‘p: bir daqiqadan keyin qayta urinib ko‘ring',
      );
    }
    if (status >= 500) {
      throw const AiException(
        'AI xizmati band: birozdan keyin qayta urinib ko‘ring',
      );
    }
    final Map data;
    try {
      data = jsonDecode(text) as Map;
    } catch (_) {
      throw AiException('AI javobi o‘qilmadi ($status)');
    }
    if (status != 200) {
      final message = (data['error'] as Map?)?['message'];
      throw AiException(
        'AI xatosi ($status)${message == null ? '' : ': $message'}',
      );
    }
    switch (data['stop_reason']) {
      case 'refusal':
        throw const AiException(
          'AI bu rasmni o‘qimadi. Boshqa rasm bilan urinib ko‘ring',
        );
      case 'max_tokens':
        throw const AiException(
          'AI javobi to‘liq kelmadi. Qayta urinib ko‘ring',
        );
    }
    final blocks = [
      for (final b in data['content'] as List? ?? const [])
        if (b is Map && b['type'] == 'text') b['text'] as String,
    ];
    if (blocks.isEmpty) throw const AiException('AI javob bermadi');
    try {
      return jsonDecode(blocks.join()) as Map;
    } catch (_) {
      throw const AiException('AI javobi o‘qilmadi');
    }
  }
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}
