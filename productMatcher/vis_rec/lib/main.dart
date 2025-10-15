// lib/main.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// For web use 127.0.0.1:8000; for Android emulator use 10.0.2.2:8000
const String BACKEND_ENDPOINT_PATH = "/match";

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Pitch-black themed app with small accent colors
    final base = ThemeData.dark();
    return MaterialApp(
      title: 'SnapNFind',
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF0F0F10),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        colorScheme: base.colorScheme.copyWith(primary: Colors.indigoAccent),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF121212),
          border: OutlineInputBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigoAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  XFile? _picked;
  Uint8List? _previewBytes;
  bool _loading = false;
  List<dynamic> _results = [];

  // default min similarity = 0.70 (70%)
  double _threshold = 0.70;

  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Filter controllers
  final TextEditingController _minPriceCtl = TextEditingController();
  final TextEditingController _maxPriceCtl = TextEditingController();
  final TextEditingController _topKController = TextEditingController(text: "6");
  int _topK = 6;

  String getBackendBase() {
    if (kIsWeb) return "http://127.0.0.1:8000";
    if (Platform.isAndroid) return "http://10.0.2.2:8000";
    return "http://localhost:8000";
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _picked = file;
        _previewBytes = bytes;
        _urlController.clear();
        _results = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pick error: $e')));
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              _topKController.text = _topKController.text.isEmpty ? "6" : _topKController.text;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(
                    children: [
                      const Expanded(child: Text("Filters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close))
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Min price (₹)"),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Max price (₹)"),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text("Min similarity", style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: _threshold,
                        onChanged: (v) => setModalState(() => _threshold = v),
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: (_threshold * 100).toStringAsFixed(0) + "%",
                      ),
                    ),
                    SizedBox(width: 56, child: Text("${(_threshold * 100).toStringAsFixed(0)}%", textAlign: TextAlign.right)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text("Top K"),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _topKController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        onChanged: (s) {
                          final v = int.tryParse(s) ?? _topK;
                          setModalState(() => _topK = v.clamp(1, 50));
                        },
                      ),
                    )
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final v = int.tryParse(_topKController.text) ?? _topK;
                          _topK = v.clamp(1, 50);
                          Navigator.of(ctx).pop();
                          setState(() {}); // update parent state
                        },
                        child: const Text("Apply"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _minPriceCtl.clear();
                          _maxPriceCtl.clear();
                          _threshold = 0.70; // reset to default 70%
                          _topK = 6;
                          _topKController.text = "6";
                        });
                      },
                      child: const Text("Reset"),
                    ),
                  ])
                ]),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_picked == null && (_urlController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an image or paste a URL')));
      return;
    }
    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      final backendBase = getBackendBase();
      var uri = Uri.parse("$backendBase$BACKEND_ENDPOINT_PATH");
      var req = http.MultipartRequest('POST', uri);

      if (_picked != null) {
        final bytes = await _picked!.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: _picked!.name));
      } else {
        req.fields['image_url'] = _urlController.text.trim();
      }

      // send filters
      req.fields['threshold'] = _threshold.toStringAsPrecision(3);
      req.fields['top_k'] = _topK.toString();
      if (_minPriceCtl.text.trim().isNotEmpty) req.fields['price_min'] = _minPriceCtl.text.trim();
      if (_maxPriceCtl.text.trim().isNotEmpty) req.fields['price_max'] = _maxPriceCtl.text.trim();

      var streamed = await req.send();
      var resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        debugPrint("DEBUG SERVER BODY: $body");
        setState(() {
          _results = body['query_matches'] ?? [];
        });
      } else {
        final body = resp.body;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server error: $body')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  String _resolveImageUrl(String rawImageUrl) {
    final backendBase = getBackendBase();
    if (rawImageUrl.isEmpty) return "";
    if (rawImageUrl.startsWith("/static")) {
      return backendBase + rawImageUrl;
    } else if (rawImageUrl.startsWith("http://") || rawImageUrl.startsWith("https://")) {
      return rawImageUrl;
    } else {
      return backendBase + "/static/" + rawImageUrl;
    }
  }

  Widget _resultCard(dynamic item) {
    final String name = (item['name'] ?? '').toString();
    final String category = (item['category'] ?? '').toString();
    final double prodScore = (item['score'] ?? 0.0).toDouble();
    final minPrice = item['min_price'];
    final maxPrice = item['max_price'];
    final List<dynamic> images = (item['images'] as List<dynamic>?) ?? [];

    Color scoreColor = prodScore >= 0.8 ? Colors.green : (prodScore >= 0.6 ? Colors.orange : Colors.red);

    String priceSummary = "";
    if (minPrice != null && maxPrice != null) {
      priceSummary = "₹${minPrice.toString()} - ₹${maxPrice.toString()}";
    } else if (minPrice != null) {
      priceSummary = "From ₹${minPrice.toString()}";
    } else if (maxPrice != null) {
      priceSummary = "Up to ₹${maxPrice.toString()}";
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).cardColor,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (priceSummary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(priceSummary, style: const TextStyle(fontSize: 12)),
                  ]
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(8)),
                child: Text(prodScore.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
              )
            ]),
          ),

          // images strip
          if (images.isNotEmpty)
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final img = images[idx] as Map<String, dynamic>;
                  final raw = (img['file'] ?? '').toString();
                  final url = _resolveImageUrl(raw);
                  final price = img['price'];
                  final imgScore = (img['score'] ?? 0.0).toDouble();

                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Theme.of(context).cardColor,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 320,
                              height: 320,
                              color: Colors.grey[900],
                              child: url.isNotEmpty
                                  ? Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                  : const Icon(Icons.broken_image),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Price: ${price != null ? '₹$price' : 'N/A'}  •  Score: ${imgScore.toStringAsFixed(3)}"),
                            ),
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close"))
                          ]),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 80,
                          decoration: BoxDecoration(color: const Color(0xFF0B0B0C), borderRadius: BorderRadius.circular(6)),
                          child: url.isNotEmpty
                              ? Image.network(url, fit: BoxFit.cover, width: 120, height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                              : const Icon(Icons.broken_image),
                        ),
                        const SizedBox(height: 6),
                        Text(price != null ? "₹$price" : "-", style: const TextStyle(fontSize: 12))
                      ],
                    ),
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("No images available", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _minPriceCtl.dispose();
    _maxPriceCtl.dispose();
    _topKController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width > 900;

    // Top gradient (very subtle) behind AppBar/title area
    final topGradient = Container(
      height: 120,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF050505), Color(0xFF0B0B0C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );

    return Scaffold(
      // extend body behind appbar so gradient appears at the top
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: AppBar(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              // gradient lettered app name for style
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF7C4DFF)]).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
                },
                child: const Text(
                  'Snap_N_Find',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white, // will be masked by shader
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Opacity(opacity: 0.65, child: Text('— Visual search', style: TextStyle(fontSize: 12))),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterSheet,
              tooltip: "Filters",
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          topGradient,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 92, 12, 12), // leave space for appbar/gradient
            child: Column(
              children: [
                // upload row
                Row(
                  children: [
                    ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo), label: const Text('Pick Image')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'Or paste image URL', hintStyle: TextStyle(color: Colors.white54)),
                        onChanged: (_) {
                          if (_urlController.text.trim().isNotEmpty) {
                            setState(() {
                              _picked = null;
                              _previewBytes = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.search), label: const Text('Search')),
                  ],
                ),
                const SizedBox(height: 12),

                // preview
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFF0B0B0C), borderRadius: BorderRadius.circular(6)),
                  child: _previewBytes != null
                      ? Image.memory(_previewBytes!, fit: BoxFit.contain)
                      : (_urlController.text.trim().isNotEmpty
                          ? Image.network(_urlController.text.trim(), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('Invalid URL')))
                          : const Center(child: Text('Preview area'))),
                ),

                const SizedBox(height: 12),

                if (_loading) const LinearProgressIndicator(),
                const SizedBox(height: 8),

                // results grid
                Expanded(
                  child: _results.isEmpty
                      ? const Center(child: Text('No results yet', style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: _results.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: wide ? 2 : 1, childAspectRatio: 1.1),
                          itemBuilder: (context, i) => _resultCard(_results[i]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
