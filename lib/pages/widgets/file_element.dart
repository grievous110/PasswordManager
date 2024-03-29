import 'dart:io';
import 'package:flutter/material.dart';
import 'package:passwordmanager/pages/other/notifications.dart';
import 'package:passwordmanager/engine/reference.dart';

/// Widget that represents a local file. Allows deletion and renaming of file.
class FileWidget extends StatefulWidget {
  const FileWidget({Key? key, required this.reference, required this.onClicked, required this.onDelete}) : super(key: key);

  final Reference<File> reference;
  final void Function(File) onClicked;
  final void Function() onDelete;

  @override
  State<FileWidget> createState() => _FileWidgetState();
}

class _FileWidgetState extends State<FileWidget> {
  late bool renaming;
  late TextEditingController renameController;
  late String _currentName;

  /// Asynchronous method to rename the file. Does nothing if provided name is empty or only consists of whitespaces.
  /// Purposefully fails if file with new name already exists.
  Future<void> _rename(String newName) async {
    try {
      if (newName.trim().isNotEmpty && newName != _currentName) {
        final int lastSeperator = widget.reference.value.path.lastIndexOf(Platform.pathSeparator);
        final String relativePath = widget.reference.value.path.substring(0, lastSeperator + 1);
        if (File('$relativePath$newName.x').existsSync()) throw Exception();
        widget.reference.assign = await widget.reference.value.rename('$relativePath$newName.x');

        setState(() {
          renaming = false;
          _currentName = newName;
        });
      } else {
        setState(() {
          renaming = false;
          renameController.text = _currentName;
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occurred!',
        content: Text(
          'Could not rename file',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
  }

  /// After user allows deletion file is deleted and [onDelete] callback is executed.
  Future<void> _deleteFileClicked() async {
    bool? delete;
    await Notify.dialog(
        context: context,
        type: NotificationType.deleteDialog,
        title: 'Are you sure?',
        content: Text(
          'Are you sure that you want to delete "${widget.reference.value.path}"?\nAction can not be undone!',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onConfirm: () {
          delete = true;
          Navigator.of(context).pop();
        });
    if (delete ?? false) {
      if (!context.mounted) return;
      Notify.showLoading(context: context);
      await widget.reference.value.delete();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      widget.onDelete();
    }
  }

  @override
  void initState() {
    renaming = false;
    final String wholeName = widget.reference.value.path.split(Platform.pathSeparator).last;
    _currentName = wholeName.substring(0, wholeName.lastIndexOf('.'));
    renameController = TextEditingController(text: _currentName);
    super.initState();
  }

  @override
  void dispose() {
    renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: ListTile(
        onTap: () => !renaming ? widget.onClicked(widget.reference.value) : null,
        leading: const Icon(
          Icons.file_open_outlined,
          size: 40.0,
        ),
        title: !renaming
            ? Text(
                widget.reference.value.path.split(Platform.pathSeparator).last,
                style: Theme.of(context).textTheme.displayMedium,
              )
            : Padding(
                padding: const EdgeInsets.only(bottom: 5.0),
                child: TextField(
                  controller: renameController,
                  autofocus: true,
                  onSubmitted: (value) => _rename(value),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 15.0),
                  ),
                  onTapOutside: (value) => setState(() {
                    renaming = false;
                    renameController.text = _currentName;
                  }),
                ),
              ),
        subtitle: Text(
          '${widget.reference.value.lengthSync()} bytes',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!renaming)
              IconButton(
                onPressed: () => setState(() {
                  renaming = true;
                }),
                icon: const Icon(
                  Icons.edit,
                  size: 30.0,
                ),
              ),
            IconButton(
              onPressed: () => !renaming ? _deleteFileClicked() : null,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 35.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
