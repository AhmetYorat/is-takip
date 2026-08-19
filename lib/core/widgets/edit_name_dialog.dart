import 'package:flutter/material.dart';

/// Ad Soyad edit dialog. A proper [StatefulWidget] so its
/// [TextEditingController] is created/disposed by Flutter's own widget
/// lifecycle (in `dispose()`) instead of manually right after `showDialog`
/// returns — disposing it early, before the dialog's exit transition
/// finishes, is what was causing a
/// `'_dependents.isEmpty': is not true` framework crash.
class EditNameDialog extends StatefulWidget {
  const EditNameDialog({
    super.key,
    required this.initialName,
    this.title = 'Adı düzenle',
  });

  final String initialName;
  final String title;

  static Future<String?> show(
    BuildContext context, {
    required String initialName,
    String title = 'Adı düzenle',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          EditNameDialog(initialName: initialName, title: title),
    );
  }

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Ad Soyad'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = _controller.text.trim();
            if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
