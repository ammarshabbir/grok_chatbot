import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';
import 'package:mime/mime.dart';

class ChatService {
  askGenAI(List<Map<String, Object>> chatHistory) async {
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
    print(response.body.toString());
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final jsonCanArray = jsonData['candidates'];
      if (jsonCanArray != null && jsonCanArray.isNotEmpty) {
        return jsonCanArray[0]["content"]["parts"][0]["text"];
      }
    } else {
      return "There is some error " + response.statusCode.toString();
    }
  }

  generateImages(String prompt) async {
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
    print(response.body.toString());
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final jsonCanArray = jsonData['candidates'];
      if (jsonCanArray != null && jsonCanArray.isNotEmpty) {
        return jsonCanArray[0]["content"]["parts"][1]["inlineData"]["data"];
      }
    } else {
      return "There is some error " + response.statusCode.toString();
    }
  }

  understandImages(String prompt, File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mime_type = lookupMimeType(imageFile.path) ?? "image/jpeg";

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
                "inline_data": {"mime_type": mime_type, "data": base64Image},
              },
            ],
          },
        ],
      }),
    );
    print(response.body.toString());
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final jsonCanArray = jsonData['candidates'];
      if (jsonCanArray != null && jsonCanArray.isNotEmpty) {
        return jsonCanArray[0]["content"]["parts"][0]["text"];
      }
    } else {
      return "There is some error " + response.statusCode.toString();
    }
  }
}
