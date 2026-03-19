import 'dart:convert';

import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

const String _xAiApiKey = String.fromEnvironment('XAI_API_KEY');

class ImageGenerationResult {
  const ImageGenerationResult({
    this.imageBase64,
    this.imageUrl,
    this.text,
    this.errorMessage,
  });

  final String? imageBase64;
  final String? imageUrl;
  final String? text;
  final String? errorMessage;

  bool get hasImage =>
      (imageBase64 != null && imageBase64!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

class ChatService {
  Future<String> askGrok(List<Map<String, Object>> chatHistory) async {
    if (_xAiApiKey.isEmpty) {
      return 'Missing XAI_API_KEY. Run with --dart-define=XAI_API_KEY=...';
    }

    final response = await post(
      Uri.parse('https://api.x.ai/v1/responses'),
      headers: {
        'Content-Type': 'application/json',
        "Authorization": 'Bearer $_xAiApiKey',
      },
      body: jsonEncode({
        "input": chatHistory,
        "model": "grok-4-latest",
        "store": false,
        "stream": false,
        "temperature": 0,
      }),
    );
    final Map<String, dynamic>? jsonData = _tryDecodeJson(response.body);

    if (response.statusCode == 200 && jsonData != null) {
      final output = jsonData['output'] as List<dynamic>?;
      if (output != null) {
        for (final item in output) {
          if (item is! Map<String, dynamic> || item["type"] != "message") {
            continue;
          }

          final content = item["content"] as List<dynamic>?;
          if (content == null) {
            continue;
          }

          for (final part in content) {
            if (part is! Map<String, dynamic>) {
              continue;
            }

            if (part["type"] == "output_text") {
              final text = part["text"]?.toString();
              if (text != null && text.isNotEmpty) {
                return text;
              }
            }
          }
        }
      }

      final fallbackText = jsonData["output_text"]?.toString();
      if (fallbackText != null && fallbackText.isNotEmpty) {
        return fallbackText;
      }
    } else {
      final apiMessage = jsonData?["error"]?["message"]?.toString();
      return apiMessage ?? 'There is some error ${response.statusCode}';
    }

    return "No response generated.";
  }

  Future<ImageGenerationResult> generateImages(String prompt) async {
    try {
      if (_xAiApiKey.isEmpty) {
        return const ImageGenerationResult(
          errorMessage:
              'Missing XAI_API_KEY. Run with --dart-define=XAI_API_KEY=...',
        );
      }

      final response = await post(
        Uri.parse('https://api.x.ai/v1/images/generations'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": 'Bearer $_xAiApiKey',
        },
        body: jsonEncode({
          "model": "grok-imagine-image",
          "prompt": prompt,
          "response_format": "b64_json",
        }),
      );

      final Map<String, dynamic>? jsonData = _tryDecodeJson(response.body);
      if (response.statusCode != 200) {
        final apiMessage = jsonData?["error"]?["message"];
        return ImageGenerationResult(
          errorMessage:
              apiMessage?.toString() ??
              "There is some error ${response.statusCode}",
        );
      }

      final data = jsonData?['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) {
        return const ImageGenerationResult(errorMessage: "No image generated.");
      }

      final imageData = data.first;
      if (imageData is! Map<String, dynamic>) {
        return const ImageGenerationResult(
          errorMessage: "Invalid image response received.",
        );
      }

      final imageBase64 = imageData["b64_json"]?.toString();
      final imageUrl = imageData["url"]?.toString();
      final text = imageData["revised_prompt"]?.toString();

      if ((imageBase64 != null && imageBase64.isNotEmpty) ||
          (imageUrl != null && imageUrl.isNotEmpty)) {
        return ImageGenerationResult(
          imageBase64: imageBase64,
          imageUrl: imageUrl,
          text: text,
        );
      }

      return ImageGenerationResult(errorMessage: text ?? "No image generated.");
    } catch (error) {
      return ImageGenerationResult(
        errorMessage: "Image generation failed: $error",
      );
    }
  }

  Future<String> understandImages(String prompt, XFile imageFile) async {
    try {
      if (_xAiApiKey.isEmpty) {
        return 'Missing XAI_API_KEY. Run with --dart-define=XAI_API_KEY=...';
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(imageFile.path) ?? "image/jpeg";

      final response = await post(
        Uri.parse('https://api.x.ai/v1/responses'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": 'Bearer $_xAiApiKey',
        },
        body: jsonEncode({
          "model": "grok-4.20-beta-latest-non-reasoning",
          "store": false,
          "input": [
            {
              "role": "user",
              "content": [
                {
                  "type": "input_image",
                  "image_url": "data:$mimeType;base64,$base64Image",
                  "detail": "high",
                },
                {"type": "input_text", "text": prompt},
              ],
            },
          ],
        }),
      );

      final Map<String, dynamic>? jsonData = _tryDecodeJson(response.body);
      if (response.statusCode != 200) {
        final apiMessage = jsonData?["error"]?["message"]?.toString();
        return apiMessage ?? "There is some error ${response.statusCode}";
      }

      if (jsonData == null) {
        return "Invalid response received.";
      }

      final outputText = jsonData["output_text"]?.toString();
      if (outputText != null && outputText.isNotEmpty) {
        return outputText;
      }

      final output = jsonData["output"] as List<dynamic>?;
      if (output != null) {
        for (final item in output) {
          if (item is! Map<String, dynamic> || item["type"] != "message") {
            continue;
          }

          final content = item["content"] as List<dynamic>?;
          if (content == null) {
            continue;
          }

          for (final part in content) {
            if (part is! Map<String, dynamic>) {
              continue;
            }

            if (part["type"] == "output_text") {
              final text = part["text"]?.toString();
              if (text != null && text.isNotEmpty) {
                return text;
              }
            }
          }
        }
      }

      return "No response generated.";
    } catch (error) {
      return "Image understanding failed: $error";
    }
  }

  Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
