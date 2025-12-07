import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  Offset _floatingPos = const Offset(20, 100);

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

  SharedPreferences? _prefs;
  
  final List<img.Image> _undoStack = [];
  final List<img.Image> _redoStack = [];
  img.Image? _dragStartImage;
  bool _isPipetteMode = false;
  final ValueNotifier<int> _imageVersion = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _loadPalette();
    _downloadImage(imageUrl1);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_editableImage!.clone());
      _editableImage = _undoStack.removeLast();
      _imageVersion.value++;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_editableImage!.clone());
      _editableImage = _redoStack.removeLast();
      _imageVersion.value++;
    });
  }

  void _recordUndoState() {
    if (_editableImage != null) {
      if (_undoStack.length >= 20) {
        _undoStack.removeAt(0);
      }
      _undoStack.add(_editableImage!.clone());
      _redoStack.clear();
    }
  }

  Future<void> _loadPalette() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String>? colorStrings = _prefs?.getStringList('custom_palette');

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
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> colorStrings =
        _palette.map((c) => c.toARGB32().toString()).toList();
    await _prefs?.setStringList('custom_palette', colorStrings);
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
      _undoStack.clear();
      _redoStack.clear();
      _imageVersion.value++;
    });
  }

  img.Image _decodeImage(Uint8List bytes) {
    return img.decodeImage(bytes)!;
  }

  void _updatePixel(int x, int y) {
    if (_editableImage == null) return;
    
    // Bounds check
    if (x < 0 || x >= _editableImage!.width || y < 0 || y >= _editableImage!.height) return;

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
    _imageVersion.value++;
  }

  Future<void> _loadImage() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await showModalBottomSheet(
        context: context,
        builder: (modalContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(modalContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(modalContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Files'),
                onTap: () {
                  Navigator.pop(modalContext);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      await _pickFile();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        _processImageBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png'],
      uniformTypeIdentifiers: ['public.image'],
    );
    final XFile? file =
        await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

    if (file == null) {
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      _processImageBytes(bytes);
    } catch (e) {
      debugPrint('Error loading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading image: $e')),
        );
      }
    }
  }

  void _processImageBytes(Uint8List bytes) {
    setState(() {
      imageBytes = bytes;
      _editableImage = null;
    });
    _convertToPixelArt();
  }

  Future<void> _saveImage() async {
    if (_editableImage == null) return;

    try {
      final pngBytes = img.encodePng(_editableImage!);
      const fileName = 'pixel_art.png';

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await showModalBottomSheet(
          context: context,
          builder: (modalContext) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Save to Photos'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    try {
                      final directory = await getTemporaryDirectory();
                      final filePath = '${directory.path}/pixel_art_${DateTime.now().millisecondsSinceEpoch}.png';
                      final file = File(filePath);
                      await file.writeAsBytes(pngBytes);
                      
                      // Request access if needed (Gal handles this usually, but good to wrap)
                      await Gal.putImage(filePath);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved to Photos!')),
                        );
                      }
                    } catch (e) {
                       debugPrint('Error saving to gallery: $e');
                       if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving to gallery: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share / Save to Files'),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    final directory = await getTemporaryDirectory();
                    final filePath = '${directory.path}/$fileName';
                    final file = File(filePath);
                    await file.writeAsBytes(pngBytes);
                    
                    // Share only the file, no text to avoid empty text files
                    await Share.shareXFiles([XFile(filePath)]);
                  },
                ),
              ],
            ),
          ),
        );
      } else {
        // Desktop/Web
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
                                onPanStart: (details) {
                                  if (_editableImage != null && !_isPipetteMode) {
                                    _dragStartImage = _editableImage!.clone();
                                  }
                                },
                                onPanUpdate: (details) {
                                  _handleInput(
                                      details.localPosition, displaySize);
                                },
                                onPanEnd: (details) {
                                  if (_dragStartImage != null) {
                                    setState(() {
                                      _undoStack.add(_dragStartImage!);
                                      _redoStack.clear();
                                      _dragStartImage = null;
                                    });
                                  }
                                },
                                onTapUp: (details) {
                                  if (!_isPipetteMode) {
                                    _recordUndoState();
                                  }
                                  _handleInput(
                                      details.localPosition, displaySize);
                                },
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    size: displaySize,
                                    painter: PixelArtPainter(_editableImage!, _imageVersion),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              
              // 2. Bottom UI (Collapsible Panel ONLY)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                      onPressed: _undoStack.isNotEmpty ? _undo : null,
                                      icon: const Icon(Icons.undo),
                                      tooltip: 'Undo',
                                    ),
                                    IconButton(
                                      onPressed: _redoStack.isNotEmpty ? _redo : null,
                                      icon: const Icon(Icons.redo),
                                      tooltip: 'Redo',
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

              // 3. Color Menu (Visible if open)
              if (_isColorMenuOpen)
                Positioned(
                  left: _floatingPos.dx,
                  top: _floatingPos.dy + 60,
                  child: Container(
                    height: 60,
                    width: 300,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      itemCount: _palette.length + 2, // +1 for Pipette at start, +1 for Add at end
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Pipette Button
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _isPipetteMode = !_isPipetteMode;
                                });
                              },
                              icon: Icon(
                                Icons.colorize, 
                                size: 24, 
                                color: _isPipetteMode ? Colors.blue : Colors.black
                              ),
                              tooltip: 'Pick Color from Image',
                            ),
                          );
                        }
                        
                        if (index == _palette.length + 1) {
                          // Color Picker Button (Moved to End)
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: IconButton(
                              onPressed: _addColor,
                              icon: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      Colors.red,
                                      Colors.green,
                                      Colors.blue,
                                      Colors.red,
                                    ],
                                  ),
                                ),
                                child: const Icon(Icons.add, size: 20, color: Colors.white),
                              ),
                              tooltip: 'Add Color',
                            ),
                          );
                        }

                        // Palette colors
                        final int paletteIndex = index - 1;
                        final color = _palette[paletteIndex];
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
                                    _isPipetteMode = false;
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
                                  onTap: () => _removeColor(paletteIndex),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              // 4. Floating Color Indicator (FAB)
              Positioned(
                left: _floatingPos.dx,
                top: _floatingPos.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _floatingPos += details.delta;
                    });
                  },
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
                    child: _isColorMenuOpen ? const Icon(Icons.close, color: Colors.white) : null,
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

    // Bounds check
    if (x < 0 || x >= _editableImage!.width || y < 0 || y >= _editableImage!.height) return;

    if (_isPipetteMode) {
      final pixel = _editableImage!.getPixel(x, y);
      final color = Color.fromARGB(
        pixel.a.toInt(), 
        pixel.r.toInt(), 
        pixel.g.toInt(), 
        pixel.b.toInt()
      );
      
      setState(() {
        if (!_palette.contains(color)) {
          _palette.add(color);
          _savePalette();
        }
        selectedColor = color;
        _isPipetteMode = false; // Disable pipette mode after picking
      });
      return;
    }

    _updatePixel(x, y);
  }
}

class PixelArtPainter extends CustomPainter {
  final img.Image image;
  final ValueNotifier<int> imageVersion;

  PixelArtPainter(this.image, this.imageVersion) : super(repaint: imageVersion);

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
     return oldDelegate.image != image;
  }
}