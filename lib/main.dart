import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Art Converter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PixelArtPage(title: 'Pixel Art Converter'),
    );
  }
}

class PixelArtPage extends StatefulWidget {
  const PixelArtPage({super.key, required this.title});

  final String title;

  @override
  State<PixelArtPage> createState() => _PixelArtPageState();
}

class _PixelArtPageState extends State<PixelArtPage> {
  // Sample image URLs for testing
  final imageUrl1 =
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQrh7NSoAFrClf1qe79cPAz-XKGWYxwJYfhqA&s';
  final imageUrl2 =
      'https://static.wikia.nocookie.net/doblaje-fanon/images/0/0f/Ñoño_animado.png/revision/latest?cb=20211113202850&path-prefix=es';
  final imageUrl3 =
      'https://www.pngplay.com/wp-content/uploads/11/Pikachu-Pokemon-Transparent-Images.png';

  final imageUrl4 =
      'https://lh3.googleusercontent.com/gps-cs-s/AC9h4npGYfST0JNslivofuasn4vk5nBlCtmJ_Qx13hX71WkEQop5gr0fz9W6_2kWxJQ8Qby9oRjL86hBv6_44AlyhfNJyEOB7UuOQhl0Gph2Bz9vYgzdXhpHjdUQmgmRxtwF6HKHl7l3ng=s680-w680-h510';

  Uint8List? imageBytes;
  img.Image? _editableImage;
  
  int _targetSize = 32;
  bool _isPanelOpen = true;
  bool _isColorMenuOpen = false;
  Color selectedColor = Colors.black;

  List<Color> _palette = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.brown,
    Colors.pink,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _loadPalette();
    _downloadImage(imageUrl1);
  }

  Future<void> _loadPalette() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? colorStrings = prefs.getStringList('custom_palette');

    if (colorStrings != null && colorStrings.isNotEmpty) {
      setState(() {
        _palette = colorStrings.map((c) => Color(int.parse(c))).toList();
        // Ensure selectedColor is in the palette, or reset it
        if (!_palette.contains(selectedColor)) {
          selectedColor = _palette.isNotEmpty ? _palette.first : Colors.black;
        }
      });
    }
  }

  Future<void> _savePalette() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> colorStrings =
        _palette.map((c) => c.toARGB32().toString()).toList();
    await prefs.setStringList('custom_palette', colorStrings);
  }

  void _addColor() {
    Color pickerColor = Colors.blue;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color!'),
        content: SingleChildScrollView(
                                  child: ColorPicker(
                                    pickerColor: pickerColor,
                                    onColorChanged: (color) {
                                      pickerColor = color;
                                    },
                                  ),        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Got it'),
            onPressed: () {
              setState(() {
                _palette.add(pickerColor);
                selectedColor = pickerColor;
              });
              _savePalette();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _removeColor(int index) {
    setState(() {
      Color removed = _palette.removeAt(index);
      if (selectedColor == removed) {
        selectedColor = _palette.isNotEmpty ? _palette.first : Colors.black;
      }
    });
    _savePalette();
  }

  Future<void> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        setState(() {
          imageBytes = response.bodyBytes;
          _editableImage = null;
        });
        _convertToPixelArt();
      } else {
        debugPrint('Error downloading image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _convertToPixelArt() {
    if (imageBytes == null) {
      return;
    }

    final myImageObject = _decodeImage(imageBytes!);

    // Ensure _targetSize is valid
    final size = _targetSize < 1 ? 32 : _targetSize;

    // Resize to create pixelated effect (downscale) and ensure square aspect ratio
    // This creates the "grid" we will edit
    img.Image resized = img.copyResizeCropSquare(
      myImageObject,
      size: size,
      interpolation: img.Interpolation.nearest,
    );

    setState(() {
      _editableImage = resized;
    });
  }

  img.Image _decodeImage(Uint8List bytes) {
    return img.decodeImage(bytes)!;
  }

  void _updatePixel(int x, int y) {
    if (_editableImage == null) return;
    
    // Bounds check
    if (x < 0 || x >= _editableImage!.width || y < 0 || y >= _editableImage!.height) return;

    setState(() {
       // Set the pixel color. 
       // image package v4 uses r, g, b, a components directly or a Color object
       // We can use clear then set or just overwrite.
       _editableImage!.setPixelRgba(
        x,
        y,
        (selectedColor.r * 255).toInt(),
        (selectedColor.g * 255).toInt(),
        (selectedColor.b * 255).toInt(),
        (selectedColor.a * 255).toInt(),
      );
    });
  }

  Future<void> _loadImage() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

    if (file == null) {
      // Operation was canceled by the user.
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      setState(() {
        imageBytes = bytes;
        _editableImage = null;
      });
      _convertToPixelArt();
    } catch (e) {
      debugPrint('Error loading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading image: $e')),
        );
      }
    }
  }

  Future<void> _saveImage() async {
    if (_editableImage == null) return;

    try {
      // Save the image at its current resolution (the pixel art grid size)
      final pngBytes = img.encodePng(_editableImage!);
      
      const fileName = 'pixel_art.png';
      final FileSaveLocation? result = await getSaveLocation(suggestedName: fileName);
      
      if (result == null) {
        // Operation was canceled by the user.
        return;
      }

      final XFile textFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: fileName,
      );

      await textFile.saveTo(result.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error saving image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    }
  }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Main Image Area
              Positioned.fill(
                child: _editableImage != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final double aspect =
                              _editableImage!.width / _editableImage!.height;
                          double displayWidth = constraints.maxWidth;
                          double displayHeight = displayWidth / aspect;
  
                          if (displayHeight > constraints.maxHeight) {
                            displayHeight = constraints.maxHeight;
                            displayWidth = displayHeight * aspect;
                          }
  
                          final displaySize = Size(displayWidth, displayHeight);
  
                          return InteractiveViewer(
                            minScale: 0.1,
                            maxScale: 50.0,
                            boundaryMargin: const EdgeInsets.all(double.infinity),
                            child: Center(
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  _handleInput(
                                      details.localPosition, displaySize);
                                },
                                onTapUp: (details) {
                                  _handleInput(
                                      details.localPosition, displaySize);
                                },
                                child: CustomPaint(
                                  size: displaySize,
                                  painter: PixelArtPainter(_editableImage!),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              
              // 2. Bottom UI (Color Menu + Collapsible Panel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Color Menu (Visible if open)
                    if (_isColorMenuOpen)
                      Container(
                                              height: 60,
                                              margin: const EdgeInsets.only(bottom: 8, left: 20, right: 16),                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _palette.length + 1, // +1 for Add button
                          itemBuilder: (context, index) {
                            if (index == _palette.length) {
                              return IconButton(
                                onPressed: _addColor,
                                icon: const Icon(Icons.add_circle, size: 32, color: Colors.blue),
                                tooltip: 'Add Color',
                              );
                            }
  
                            final color = _palette[index];
                            final isSelected = selectedColor == color;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedColor = color;
                                      });
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? Border.all(
                                                color: Colors.blueAccent, width: 3)
                                            : Border.all(
                                                color: Colors.grey[300]!, width: 1),
                                      ),
                                    ),
                                  ),
                                                                  Positioned(
                                                                    right: 0,
                                                                    top: 0,
                                                                    child: GestureDetector(
                                                                      onTap: () => _removeColor(index),
                                                                      child: const Icon(
                                                                        Icons.close,
                                                                        size: 14,
                                                                        color: Colors.black,
                                                                      ),
                                                                    ),
                                                                  ),                                ],
                              ),
                            );
                          },
                        ),
                      ),
  
                    // Collapsible Bottom Panel
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPanelOpen = !_isPanelOpen;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Icon(
                              _isPanelOpen
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        if (_isPanelOpen)
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      onPressed: _loadImage,
                                      icon: const Icon(Icons.file_open),
                                      tooltip: 'Load Image',
                                    ),
                                    IconButton(
                                      onPressed: _saveImage,
                                      icon: const Icon(Icons.save),
                                      tooltip: 'Save Image',
                                    ),
                                    IconButton(
                                      onPressed: _convertToPixelArt,
                                      icon: const Icon(Icons.refresh),
                                      tooltip: 'Reload Image',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text('Resolution:',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: _targetSize.toDouble(),
                                        min: 8,
                                        max: 128,
                                        divisions: 120,
                                        label: _targetSize.toString(),
                                        onChanged: (value) {
                                          setState(() {
                                            _targetSize = value.toInt();
                                            _convertToPixelArt();
                                          });
                                        },
                                      ),
                                    ),
                                    Text('${_targetSize}x$_targetSize'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 3. Floating Color Indicator (FAB)
            Positioned(
              left: 20,
              bottom: 20, // Keep this fixed as per floating circle behavior
              child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isColorMenuOpen = !_isColorMenuOpen;
                    });
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isColorMenuOpen ? const Icon(Icons.close, color: Colors.white) : null, // Optional icon
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  void _handleInput(Offset localPosition, Size displaySize) {
    if (_editableImage == null) return;

    final x =
        (localPosition.dx / displaySize.width * _editableImage!.width).floor();
    final y =
        (localPosition.dy / displaySize.height * _editableImage!.height).floor();

    _updatePixel(x, y);
  }
}

class PixelArtPainter extends CustomPainter {
  final img.Image image;

  PixelArtPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final pixelWidth = size.width / image.width;
    final pixelHeight = size.height / image.height;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        paint.color = Color.fromARGB(
            pixel.a.toInt(), pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
        
        // Draw slightly larger to avoid grid lines due to antialiasing? 
        // Or just exact.
        canvas.drawRect(
            Rect.fromLTWH(x * pixelWidth, y * pixelHeight, pixelWidth + 0.5, pixelHeight + 0.5),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelArtPainter oldDelegate) {
     return true; // We can optimize this later if needed
  }
}