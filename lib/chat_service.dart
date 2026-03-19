import 'dart:convert';

import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class ImageGenerationResult {
  const ImageGenerationResult({this.imageBase64, this.text, this.errorMessage});

  final String? imageBase64;
  final String? text;
  final String? errorMessage;

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

class ChatService {
  Future<String> askGenAI(List<Map<String, Object>> chatHistory) async {
    final response = await post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
      ),
      headers: {
        'Content-Type': 'application/json',
        "x-goog-api-key": 'AIzaSyA8r7ZeZdV8lZf5PK5elQzxQB2ggSVTHlY',
      },
      body: jsonEncode({
        "system_instruction": {
          "parts": [
            {"text": "you are a helpful assistant"},
          ],
        },
        "contents": chatHistory,
        "generationConfig": {
          "thinkingConfig": {"thinkingBudget": 0},
        },
      }),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final jsonCanArray = jsonData['candidates'];
      if (jsonCanArray != null && jsonCanArray.isNotEmpty) {
        return jsonCanArray[0]["content"]["parts"][0]["text"];
      }
    } else {
      return "There is some error ${response.statusCode}";
    }

    return "No response generated.";
  }

  Future<ImageGenerationResult> generateImages(String prompt) async {
    try {
      final response = await post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent',
        ),
        headers: {
          'Content-Type': 'application/json',
          "x-goog-api-key": 'AIzaSyA8r7ZeZdV8lZf5PK5elQzxQB2ggSVTHlY',
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
          "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"],
          },
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

      final candidates = jsonData?['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return const ImageGenerationResult(errorMessage: "No image generated.");
      }

      final parts =
          candidates.first["content"]?["parts"] as List<dynamic>? ?? const [];

      String? text;
      String? imageBase64;
      for (final part in parts) {
        if (part is! Map<String, dynamic>) {
          continue;
        }

        text ??= part["text"]?.toString();
        imageBase64 ??= part["inlineData"]?["data"]?.toString();
      }

      if (imageBase64 != null && imageBase64.isNotEmpty) {
        return ImageGenerationResult(imageBase64: imageBase64, text: text);
      }

      return ImageGenerationResult(errorMessage: text ?? "No image generated.");
    } catch (error) {
      return ImageGenerationResult(
        errorMessage: "Image generation failed: $error",
      );
    }
  }

  Future<String> understandImages(String prompt, XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = lookupMimeType(imageFile.path) ?? "image/jpeg";

    final response = await post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
      ),
      headers: {
        'Content-Type': 'application/json',
        "x-goog-api-key": 'AIzaSyA8r7ZeZdV8lZf5PK5elQzxQB2ggSVTHlY',
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {"mime_type": mimeType, "data": base64Image},
              },
            ],
          },
        ],
      }),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final jsonCanArray = jsonData['candidates'];
      if (jsonCanArray != null && jsonCanArray.isNotEmpty) {
        return jsonCanArray[0]["content"]["parts"][0]["text"];
      }
    } else {
      return "There is some error ${response.statusCode}";
    }

    return "No response generated.";
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
