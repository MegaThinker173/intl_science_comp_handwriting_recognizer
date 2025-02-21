import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Handwritten Math Recognizer',
      home: HomePage(),
    );
  }
}

// Update Stroke class to store color and strokeWidth.
class Stroke {
  List<Offset> points;
  Color color;
  double strokeWidth;
  Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _canvasKey = GlobalKey();
  List<Stroke> strokes = [];
  Stroke? currentStroke;

  bool isProcessing = false;
  String latexOutput = "";

  // Brush settings: initial color black, brush size 4.0.
  Color selectedColor = Colors.black;
  double brushSize = 4.0;

  Future<void> recognizeMath() async {
    setState(() {
      isProcessing = true;
      latexOutput = "";
    });
    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      String responseLatex = await sendImageForMathRecognition(pngBytes);
      setState(() {
        latexOutput = responseLatex;
      });
    } catch (e) {
      setState(() {
        latexOutput = "Error: $e";
      });
    }
    setState(() {
      isProcessing = false;
    });
  }

  Future<String> sendImageForMathRecognition(Uint8List imageBytes) async {
    // Update the URL if necessary.
    final url = Uri.parse("http://localhost:5001/recognize_math");
    var request = http.MultipartRequest("POST", url);
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: 'handwriting.png',
      contentType: MediaType('image', 'png'),
    ));
    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);
      return jsonResponse['latex'] as String? ?? "No LaTeX found";
    } else {
      return "Server error: ${response.statusCode}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Handwritten Math Recognizer'),
      ),
      body: Column(
        children: [
          // Brush color selection.
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                colorOption(Colors.black),
                colorOption(Colors.red),
                colorOption(Colors.blue),
                colorOption(Colors.green),
                colorOption(Colors.orange),
              ],
            ),
          ),
          // Brush size slider.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text("Brush Size"),
                Expanded(
                  child: Slider(
                    min: 1.0,
                    max: 20.0,
                    value: brushSize,
                    onChanged: (newSize) {
                      setState(() {
                        brushSize = newSize;
                      });
                    },
                  ),
                ),
                Text(brushSize.toStringAsFixed(1)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Drawing canvas.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
            ),
            child: RepaintBoundary(
              key: _canvasKey,
              child: GestureDetector(
                onPanStart: (details) {
                  final RenderBox box = _canvasKey.currentContext!
                      .findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);
                  if (localPos.dx >= 0 &&
                      localPos.dy >= 0 &&
                      localPos.dx <= box.size.width &&
                      localPos.dy <= box.size.height) {
                    setState(() {
                      currentStroke = Stroke(
                        points: [localPos],
                        color: selectedColor,
                        strokeWidth: brushSize,
                      );
                      strokes.add(currentStroke!);
                    });
                  }
                },
                onPanUpdate: (details) {
                  final RenderBox box = _canvasKey.currentContext!
                      .findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);
                  if (localPos.dx >= 0 &&
                      localPos.dy >= 0 &&
                      localPos.dx <= box.size.width &&
                      localPos.dy <= box.size.height) {
                    setState(() {
                      currentStroke?.points.add(localPos);
                    });
                  }
                },
                onPanEnd: (details) {
                  setState(() {
                    currentStroke = null;
                  });
                },
                child: CustomPaint(
                  painter: DrawingPainter(strokes),
                  child: Container(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Buttons.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    strokes.clear();
                  });
                },
                child: const Text("Clear"),
              ),
              ElevatedButton(
                onPressed: isProcessing ? null : recognizeMath,
                child: const Text("Recognize Math"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isProcessing) const CircularProgressIndicator(),
          if (!isProcessing && latexOutput.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              child: Math.tex(
                latexOutput,
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Widget to display a selectable color option.
  Widget colorOption(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selectedColor == color ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
