import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../services/photo_saver.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _files = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final files = await PhotoSaver.savedPhotos();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(child: Text('No photos yet'))
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _files.length,
                  itemBuilder: (context, i) {
                    final f = _files[i];
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _PhotoViewer(file: f),
                          ),
                        );
                        _reload();
                      },
                      child: Image.file(
                        f,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                      ),
                    );
                  },
                ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.file});
  final File file;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text(
            'This removes the copy kept inside the app. The copy in your '
            'phone gallery is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await file.delete();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(file.uri.pathSegments.last),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(
              ShareParams(files: [XFile(file.path)]),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.file(file),
        ),
      ),
    );
  }
}
