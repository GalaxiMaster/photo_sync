import 'package:flutter/material.dart';

Widget buildDropdown(String hint, {List? items, Function(String? value)? onChange}) {
  return DropdownButton<String>(
    isExpanded: true,
    value: null,
    hint: Text(hint, style: const TextStyle(color: Colors.white38)),
    dropdownColor: const Color(0xFF2C2F33),
    style: const TextStyle(color: Colors.white),
    underline: const SizedBox(),
    items: items != null ? [
      ...items.map((item) => DropdownMenuItem(value: item, child: Text(item))),
    ] : [],
    onChanged: (newValue) => onChange?.call(newValue),
  );
}

class TagChip extends StatefulWidget {
  final String tag;
  final VoidCallback onDelete;
  const TagChip({required this.tag, required this.onDelete, super.key});

  @override
  State<TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<TagChip> {
  final _hovering = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hovering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Container(
        height: 25,
        decoration: BoxDecoration(
          borderRadius: BorderRadiusGeometry.only(topRight: Radius.circular(15), bottomRight: Radius.circular(15)),
          color: Colors.blue.shade300,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.only(left: 8),
              child: Text(widget.tag, style: const TextStyle(color: Colors.black)),
            ),
            MouseRegion(
              onEnter: (_) => _hovering.value = true,
              onExit: (_) => _hovering.value = false,
              child: ClipRRect(
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _hovering,
                    builder: (_, hovering, _) => Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: hovering ? Colors.blue.shade400 :Colors.blue.shade300,
                        borderRadius: BorderRadiusGeometry.only(topRight: Radius.circular(15), bottomRight: Radius.circular(15)),
                      ),
                      child: Icon(Icons.close, size: 14, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}