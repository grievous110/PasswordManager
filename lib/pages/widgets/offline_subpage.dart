import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:passwordmanager/pages/mobile_file_selection_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:passwordmanager/engine/local_database.dart';
import 'package:passwordmanager/engine/safety.dart';
import 'package:passwordmanager/engine/persistence.dart';
import 'package:passwordmanager/engine/source.dart';
import 'package:passwordmanager/pages/password_getter_page.dart';
import 'package:passwordmanager/pages/manage_page.dart';
import 'package:passwordmanager/pages/other/notifications.dart';

class OfflinePage extends StatelessWidget {
  const OfflinePage({Key? key}) : super(key: key);

  /// Tries to open the last save file through the [Settings.lastOpenedPath] property.
  /// Cases an error is thrown:
  /// * The file does not exist anymore
  /// * The file could not be correctly decrypted / wrong password
  /// * Everything worked but there was not at least one account loaded in the [LocalDatabase]
  Future<void> _openLast(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LocalDatabase database = LocalDatabase();
    final Settings settings = context.read<Settings>();
    final File file = File(context.read<Settings>().lastOpenedPath);

    try {
      if (!file.existsSync()) throw Exception('File does not exist');
      await Guardian.failIfAccessDenied(() async {
        String? pw = await navigator.push(
          MaterialPageRoute(
            builder: (context) => PasswordGetterPage(
              path: context.read<Settings>().lastOpenedPath,
              title: 'Enter password',
            ),
          ),
        );

        if (pw == null) return;
        database.setSource(Source(sourceFile: file));

        try {
          if (!context.mounted) return;
          Notify.showLoading(context: context);
          await database.load(password: pw, legacyMode: settings.useLegacyAccessEnabled);
        } catch (e) {
          navigator.pop();
          Guardian.callAccessFailed('Wrong password');
        }
        navigator.pop();

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ManagePage(),
          ),
          (route) => false,
        );
      });
    } catch (e) {
      database.clear(notify: false);
      if (!context.mounted) return;
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occurred!',
        content: Text(
          e.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
  }

  /// Tries to open a save file by using the platform specific filepicker.
  /// Cases an error is thrown:
  /// * The file extension is NOT ".x"
  /// * The file could not be correctly decrypted / wrong password
  /// * Everything worked but there was not at least one account loaded in the [LocalDatabase]
  /// * An unknown error occurred
  Future<void> _selectFile(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LocalDatabase database = LocalDatabase();
    final Settings settings = context.read<Settings>();

    try {
      await Guardian.failIfAccessDenied(() async {
        File? file;
        if (Settings.isWindows) {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            lockParentWindow: true,
            dialogTitle: 'Select your save file',
            type: FileType.any,
            allowCompression: false,
            //allowedExtensions: ['x'],
            allowMultiple: false,
          );

          if (result != null) {
            file = File(result.files.single.path!);
          }
        } else {
          final Directory? dir = await getExternalStorageDirectory();
          if(dir == null) throw Exception('Could not receive storage directory');
          file = await navigator.push(MaterialPageRoute(builder: (context) => MobileFileSelectionPage(dir: dir)));
        }

        if (file == null) return;

        if (!file.path.endsWith('.x')) {
          throw Exception('File extension is not supported');
        }

        String? pw = await navigator.push(
          MaterialPageRoute(
            builder: (context) => PasswordGetterPage(
              path: file?.path,
              title: 'Enter password',
            ),
          ),
        );

        if (pw == null || !file.existsSync()) return;
        database.setSource(Source(sourceFile: file));

        try {
          if (!context.mounted) return;
          Notify.showLoading(context: context);
          await database.load(password: pw, legacyMode: settings.useLegacyAccessEnabled);
        } catch (e) {
          navigator.pop();
          Guardian.callAccessFailed('Wrong password');
        }
        navigator.pop();

        settings.setLastOpenedPath(file.path);
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ManagePage(),
          ),
          (route) => false,
        );
      });
    } catch (e) {
      database.clear(notify: false);
      if (!context.mounted) return;
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occurred!',
        content: Text(
          e.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
  }

  /// Creates a save file in the selected directory.
  /// Note: the file itself is only created once the [LocalDatabase] saves for the first time.
  /// Cases an error is thrown:
  /// * An unknown error occurred
  /// * Special case (nothing happens): The autogenerate did not find a file that did not already exist before.
  Future<void> _createFile(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LocalDatabase database = LocalDatabase();
    final Settings settings = context.read<Settings>();

    try {
      String? path;
      if (Settings.isWindows) {
        path = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select directory for save file',
          lockParentWindow: true,
        );
      } else {
        final Directory? dir = await getExternalStorageDirectory();
        if(dir == null) throw Exception('Could not receive storage directory');
        path = dir.path;
      }

      if (path == null) return;

      int counter = 0;
      File file = File('$path${Platform.pathSeparator}save.x');
      while (file.existsSync()) {
        counter++;
        file = File('$path${Platform.pathSeparator}save-$counter.x');
        if (counter > 9999) break;
      }
      if (file.existsSync()) return;

      String? pw = await navigator.push(
        MaterialPageRoute(
          builder: (context) => PasswordGetterPage(
            path: file.path,
            title: 'Set password for new file',
            showIndicator: true,
          ),
        ),
      );

      if (pw == null) return;
      database.setSource(Source(sourceFile: file));

      try {
        if (!context.mounted) return;
        Notify.showLoading(context: context);
        await database.source!.initialiseNewSource(password: pw);
      } catch(e) {
        navigator.pop();
        throw Exception('Could not initialise new file');
      }
      navigator.pop();

      settings.setLastOpenedPath(file.path);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const ManagePage(),
        ),
        (route) => false,
      );
    } catch (e) {
      database.clear(notify: false);
      if (!context.mounted) return;
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occurred!',
        content: Text(
          e.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            SizedBox(
              width: 560,
              height: 120,
              child: context.read<Settings>().isLightMode ? SvgPicture.asset('assets/lightLogo.svg') : SvgPicture.asset('assets/darkLogo.svg'),
            ),
            Text(
              'Select your save file:',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 15.0),
            ElevatedButton(
              onPressed: () => _selectFile(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25.0, vertical: 2.5),
                child: Icon(
                  Icons.search,
                  size: 40,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(height: 35),
        Consumer<Settings>(
          builder: (context, settings, child) => settings.lastOpenedPath.isNotEmpty
              ? TextButton(
                  onPressed: () => _openLast(context),
                  child: Text(
                    'Open last: ${settings.lastOpenedPath}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      overflow: Theme.of(context).textTheme.bodySmall!.overflow,
                    ),
                  ),
                )
              : Container(),
        ),
        const Spacer(),
        const SizedBox(height: 35),
        Column(
          children: [
            Text(
              'No save file?',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            TextButton(
              onPressed: () => _createFile(context),
              child: const Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  'Create a new one',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
