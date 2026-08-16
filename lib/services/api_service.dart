import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : 'Bearer demo-token',
    };
  }

  Future<Map<String, dynamic>> visionAnalysis(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/vision'),
      headers: await _headers(),
      body: jsonEncode({
        'image': base64Image,
        'prompt':
            'Identify all food items in this image. For each item, provide: '
                'name, estimated quantity, unit, category, and type '
                '(raw/packaged/leftover). Return as a JSON array.',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Vision analysis failed: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> billOcrScan(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/ocr'),
      headers: await _headers(),
      body: jsonEncode({'image': base64Image}),
    );

    if (response.statusCode != 200) {
      throw Exception('OCR scan failed: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<String> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> pantryContext,
    bool chefMode = false,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/chat'),
      headers: await _headers(),
      body: jsonEncode({
        'message': message,
        'pantry': pantryContext,
        'chefMode': chefMode,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Chat failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['reply'] ?? 'Sorry, I could not process that.';
  }

  Future<Map<String, dynamic>> generateRecipe({
    required List<Map<String, dynamic>> availableIngredients,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/recipe'),
      headers: await _headers(),
      body: jsonEncode({'ingredients': availableIngredients}),
    );

    if (response.statusCode != 200) {
      throw Exception('Recipe generation failed: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> estimateConsumption({
    required Map<String, dynamic> recipe,
    required List<Map<String, dynamic>> currentPantry,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/estimate'),
      headers: await _headers(),
      body: jsonEncode({
        'recipe': recipe,
        'pantry': currentPantry,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Estimation failed: ${response.body}');
    }

    return jsonDecode(response.body);
  }
}
