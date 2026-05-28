import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/tag_provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

class TagPopup extends ConsumerStatefulWidget {
  final ImmichTag? selectedTag;
  final bool editingMode;
  const TagPopup({super.key, required this.selectedTag, this.editingMode = false});

  @override
  ConsumerState<TagPopup> createState() => _TagPopupState();
}

class _TagPopupState extends ConsumerState<TagPopup> {
  late final TextEditingController nameController;
  late final TextEditingController _hexController;

  Color _color = Colors.white;

  @override
  void initState() {
    super.initState();
    _color = widget.selectedTag?.color ?? Colors.white;
    nameController = TextEditingController(
      text: widget.selectedTag != null
        ? '${widget.selectedTag!.value ?? widget.selectedTag!.name}/'
        : '',
    );
    _hexController = TextEditingController(
      text: _color.toARGB32().toRadixString(16).substring(2),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.editingMode ? "Edit Tag" : "Create Tag",
        style: TextStyle(fontSize: 18),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.editingMode)...[
              Text('Create a new tag. For nested tags, please enter the full path of the tag including forward slashes'),
              TextFormField(
                controller: nameController,
              ),
            ],
            if (widget.editingMode)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ColorPicker(
                    color: _color,
                    onColorChanged: (color) {
                      setState(() {
                        _color = color;
                        _hexController.text = color.toARGB32()
                            .toRadixString(16)
                            .padLeft(8, '0')
                            .substring(2);
                      });
                    },
                    pickersEnabled: const {
                      ColorPickerType.wheel: true,
                      ColorPickerType.primary: false,
                      ColorPickerType.accent: false,
                    },
                    enableShadesSelection: false,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _hexController,
                        decoration: const InputDecoration(
                          prefixText: '#',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (val) {
                          final hex = int.tryParse('ff$val', radix: 16);
                          if (hex != null) setState(() => _color = Color(hex));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context), 
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Color.fromARGB(255, 30, 30, 30)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16
              ),
            ),
          )
        ),
        ElevatedButton(
          onPressed: (){
            final List<String> path = nameController.text.split('/');
            final String name = path.last;
            final String? parentId = ref.read(tagStoreProvider.notifier).getIdFromPath(path.sublist(0, path.length - 1).join('/'))?.id;
            final ImmichTag newTag = ImmichTag(
              id: '', 
              name: name, 
              color: _color,
              createdAt: DateTime.now(), 
              updatedAt: DateTime.now(),
              parentId: parentId,
              value: path.join('/')
            );
            Navigator.pop(context, newTag);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Color.fromARGB(255, 30, 30, 30)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Create',
              style: TextStyle(
                fontSize: 16
              ),
            ),
          )
        )
      ],
    );
  }

}

class AddTagPopup extends StatefulWidget {
  const AddTagPopup({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _AddTagPopupState createState() => _AddTagPopupState();
}

class _AddTagPopupState extends State<AddTagPopup> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Tag to Assets'),
      content: SizedBox(
        width: 400,
        child: Column(
          children: [
            
          ],
        ),
      ),
    );
  }

}