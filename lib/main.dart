import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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
  Color selectedColor = Colors.black;

  final List<Color> _palette = [
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
    _downloadImage(imageUrl1);
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
        child: Column(
          children: [
            Expanded(
              child: _editableImage != null
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate size that fits within constraints while maintaining aspect ratio
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
                    padding: const EdgeInsets.all(16.0),
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
                        const Text('Tools',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _palette.length,
                            itemBuilder: (context, index) {
                              final color = _palette[index];
                              final isSelected = selectedColor == color;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 40,
                                  height: 40,
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
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('Resolution:'),
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