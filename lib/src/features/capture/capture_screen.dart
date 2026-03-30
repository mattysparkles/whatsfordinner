import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/primary_scaffold.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _images = <CapturedImage>[];
  CaptureCategory _category = CaptureCategory.pantry;

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Scan Ingredients',
      body: ListView(
        children: [
          DropdownButton<CaptureCategory>(
            value: _category,
            isExpanded: true,
            items: CaptureCategory.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          ElevatedButton(
            onPressed: () => setState(() {
              _images.add(CapturedImage(id: const Uuid().v4(), path: 'mock/path.jpg', category: _category));
            }),
            child: const Text('Add photo/screenshot'),
          ),
          Text('${_images.length} files selected'),
          const Divider(),
          ElevatedButton(
            onPressed: _images.isEmpty
                ? null
                : () async {
                    final parsed = await ref.read(visionServiceProvider).parseImages(_images);
                    if (!mounted) return;
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => ListView(
                        children: parsed
                            .map((e) => CheckboxListTile(
                                  value: true,
                                  onChanged: (_) {},
                                  title: Text(e.suggestedName),
                                  subtitle: Text('confidence ${(e.confidence * 100).round()}% · raw: ${e.rawText}'),
                                ))
                            .toList(),
                      ),
                    );
                  },
            child: const Text('Preview detected ingredients'),
          ),
        ],
      ),
    );
  }
}
