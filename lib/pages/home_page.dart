import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:passwordmanager/pages/cloud_access_page.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:passwordmanager/engine/local_database.dart';
import 'package:passwordmanager/engine/persistance.dart';
import 'package:passwordmanager/engine/source.dart';
import 'package:passwordmanager/pages/manage_page.dart';
import 'package:passwordmanager/pages/password_getter_page.dart';
import 'package:passwordmanager/pages/widgets/home_navbar.dart';
import 'package:passwordmanager/pages/other/notifications.dart';

/// The entry point of the application where cloud or offline mode can be swapped between.
/// Can display the current version information and provides options for:
/// * Offline: Searching a save file
/// * Offline: Reopening the last save file (only on Windows)
/// * Offline: Creating a new save file (only on Windows)
/// * Online: Access storage data
/// * Online: Create new storage
class HomePage extends StatelessWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  /// Displays the current app information such as the version number.
  /// Additionally shows a link to the github repository.
  Future<void> _displayInfo(BuildContext context) async {
    PackageInfo info = await PackageInfo.fromPlatform();

    if (!context.mounted) return;
    Notify.dialog(
      context: context,
      type: NotificationType.notification,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 560,
              height: 80,
              child: context.read<Settings>().isLightMode
                  ? SvgPicture.asset('assets/lightLogo.svg')
                  : SvgPicture.asset('assets/darkLogo.svg'),
            ),
            Text(
              'Version: ${info.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 25.0),
              child: TextButton(
                onPressed: () async => await launchUrl(Uri.parse(
                    'https://github.com/grievous110/PasswordManager/tree/main')),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.code),
                    Padding(
                      padding: EdgeInsets.only(left: 5.0),
                      child: Text('View code'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5.0, bottom: 25),
              child: TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Ethercrypt',
                  applicationIcon: const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Icon(Icons.shield_outlined),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copyright),
                    Padding(
                      padding: EdgeInsets.only(left: 5.0),
                      child: Text('Licenses'),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'created by:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Joel Lutz',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const HomeNavBar(),
      appBar: AppBar(
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _displayInfo(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
        ],
        title: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 5.0),
              child: Icon(Settings.isWindows
                  ? Icons.desktop_windows_outlined
                  : Icons.phone_android_outlined),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
          color: Theme.of(context).colorScheme.background,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Consumer<Settings>(
                      builder: (context, settings, child) =>
                          settings.isOnlineModeEnabled
                              ? const OnlinePage()
                              : const OfflinePage(),
                    )),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final File file = File(context.read<Settings>().lastOpenedPath);

    try {
      if (!file.existsSync()) throw Exception('File does not exist');

      String? pw = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PasswordGetterPage(
            path: context.read<Settings>().lastOpenedPath,
            title: 'Enter password',
          ),
        ),
      );

      if (pw == null) return;
      database.setSource(Source(sourceFile: file), pw);

      try {
        if (!context.mounted) return;
        Notify.showLoading(context: context);
        await database.load();
      } catch (e) {
        navigator.pop();
        throw Exception('Error during decryption');
      }
      navigator.pop();

      if (database.accounts.isEmpty && file.lengthSync() > 0) {
        throw Exception('Found no relevant data in file');
      } else {
        navigator.push(
          MaterialPageRoute(
            builder: (context) => const ManagePage(title: 'Your accounts'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occured!',
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
  /// * An unknown error occured
  Future<void> _selectFile(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LocalDatabase database = LocalDatabase();
    final Settings settings = context.read<Settings>();

    if (!Platform.isWindows) await FilePicker.platform.clearTemporaryFiles();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        lockParentWindow: true,
        dialogTitle: 'Select your save file',
        type: FileType.any,
        allowCompression: false,
        //allowedExtensions: ['x'],
        allowMultiple: false,
      );

      if (result == null) return;

      final File file = File(result.files.single.path ?? '');

      if (!file.path.endsWith('.x')) {
        throw Exception('File extension is not supported');
      }

      String? pw = await navigator.push(
        MaterialPageRoute(
          builder: (context) => PasswordGetterPage(
            path: file.path,
            title: 'Enter password',
          ),
        ),
      );

      if (pw == null || !file.existsSync()) return;
      database.setSource(Source(sourceFile: file), pw);

      try {
        if (!context.mounted) return;
        Notify.showLoading(context: context);
        await database.load();
      } catch (e) {
        navigator.pop();
        throw Exception('Error during decryption');
      }
      navigator.pop();

      if (database.accounts.isEmpty && file.lengthSync() > 0) {
        throw Exception('Found no relevant data in file');
      } else {
        settings.setLastOpenedPath(file.path);
        navigator.push(
          MaterialPageRoute(
            builder: (context) => const ManagePage(title: 'Your accounts'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occured!',
        content: Text(
          e.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
  }

  /// Tries to "create" the last save file through the [Settings.lastOpenedPath] property.
  /// Note: the file itself is only created once the [LocalDatabase] saves for the first time.
  /// Cases an error is thrown:
  /// * An unknown error occured
  /// * Special case (nothing happens): The autogeneration didnt find a file that did not already exist before.
  Future<void> _createFile(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LocalDatabase database = LocalDatabase();
    final Settings settings = context.read<Settings>();

    try {
      String? path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select directory for save file',
        lockParentWindow: true,
      );

      if (path == null) return;

      File file;
      int counter = 0;
      file = File('$path${Platform.pathSeparator}save.x');
      while (file.existsSync()) {
        counter++;
        file = File('$path${Platform.pathSeparator}save-$counter.x');
      }
      if (file.existsSync()) return;

      String? pw = await navigator.push(
        MaterialPageRoute(
          builder: (context) => PasswordGetterPage(
            path: file.path,
            title: 'Set password for new file',
          ),
        ),
      );

      if (pw == null) return;
      database.setSource(Source(sourceFile: file), pw);

      settings.setLastOpenedPath(file.path);
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const ManagePage(title: 'Your accounts'),
        ),
      );
    } catch (e) {
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Unknown error',
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
              child: context.read<Settings>().isLightMode
                  ? SvgPicture.asset('assets/lightLogo.svg')
                  : SvgPicture.asset('assets/darkLogo.svg'),
            ),
            Text(
              'Select your save file:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 15.0),
            ElevatedButton(
              style: ButtonStyle(
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                ),
              ),
              onPressed: () => _selectFile(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25.0, vertical: 2.5),
                child: Icon(
                  Settings.isWindows ? Icons.search : Icons.remove_red_eye,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(height: 35),
        if (Settings.isWindows) ...[
          Consumer<Settings>(
            builder: (context, settings, child) =>
                settings.lastOpenedPath.isNotEmpty
                    ? TextButton(
                        onPressed: () => _openLast(context),
                        child: Text(
                          'Open last: ${settings.lastOpenedPath}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.fontSize,
                          ),
                          textAlign: TextAlign.center,
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
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: () => _createFile(context),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    'Create a new one',
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.bodyMedium?.fontSize,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class OnlinePage extends StatelessWidget {
  const OnlinePage({Key? key}) : super(key: key);

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
              child: context.read<Settings>().isLightMode
                  ? SvgPicture.asset('assets/lightLogo.svg')
                  : SvgPicture.asset('assets/darkLogo.svg'),
            ),
            Text(
              'Access existing cloud storage:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 15.0),
            ElevatedButton(
              style: ButtonStyle(
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                ),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const CloudAccessPage(login: true))),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25.0, vertical: 2.5),
                child: Icon(
                  Icons.login,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          children: [
            Text(
              'No cloud storage?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const CloudAccessPage(login: false))),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  'Register a new storage',
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
