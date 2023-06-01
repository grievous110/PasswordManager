import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:passwordmanager/engine/local_database.dart';
import 'package:passwordmanager/engine/persistance.dart';
import 'package:passwordmanager/pages/manage_page.dart';
import 'package:passwordmanager/pages/password_getter_page.dart';
import 'package:passwordmanager/pages/widgets/home_navbar.dart';
import 'package:passwordmanager/pages/other/notifications.dart';

/// The entry point of the application. Can display the current version information and provides options for:
/// * Searching a save file
/// * Reopening the last save file
/// * Creating a new save file
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
            const SizedBox(height: 25),
            TextButton(
              onPressed: () async => await launchUrl(Uri.parse('https://github.com/grievous110/PasswordManager/tree/main')),
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
            const SizedBox(height: 25),
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

  /// Tries to open the last save file through the [Settings.lastOpenedPath] property.
  /// Cases an error is thrown:
  /// * The file does not exist anymore
  /// * The file could not be correctly decrypted / wrong password
  /// * Everything worked but there was not at least one account loaded in the [LocalDatabase]
  Future<void> _openLast(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final LocalDatabase database = LocalDatabase();
    final File file = File(context.read<Settings>().lastOpenedPath);

    if (!file.existsSync()) {
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occured!',
        content: Text(
          'File does not exist',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
      return;
    }

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
    database.setSource(file, pw);

    try {
      if (!context.mounted) return;
      Notify.showLoading(context: context);
      await database.load();
    } catch (e) {
      if (!context.mounted) return;
      await Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Error occured!',
        content: Text(
          'Error during decryption',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
      navigator.pop();
      return;
    }
    navigator.pop();

    if (database.accounts.isEmpty && file.lengthSync() > 0) {
      if (!context.mounted) return;
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Found no relevant data in file',
      );
    } else {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const ManagePage(title: 'Your accounts'),
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

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        lockParentWindow: true,
        dialogTitle: 'Select your save file',
        type: FileType.any,
        //allowedExtensions: ['x'],
        allowMultiple: false,
      );

      if (result == null) return;

      final File file = File(result.files.single.path ?? '');

      if (!file.path.endsWith('.x')) {
        if (context.mounted) {
          Notify.dialog(
            context: context,
            type: NotificationType.error,
            title: 'Error occured!',
            content: Text(
              'File extension is not supported',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return;
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
      database.setSource(file, pw);

      try {
        if (!context.mounted) return;
        Notify.showLoading(context: context);
        await database.load();
      } catch (e) {
        if (!context.mounted) return;
        await Notify.dialog(
          context: context,
          type: NotificationType.error,
          title: 'Error occured!',
          content: Text(
            'Error during decryption',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
        navigator.pop();
        return;
      }
      navigator.pop();

      if (database.accounts.isEmpty && file.lengthSync() > 0) {
        if (!context.mounted) return;
        Notify.dialog(
          context: context,
          type: NotificationType.error,
          title: 'Found no relevant data in file',
        );
      } else {
        settings.setLastOpenedPath(file.path);
        navigator.push(
          MaterialPageRoute(
            builder: (context) => const ManagePage(title: 'Your accounts'),
          ),
        );
      }
    } catch (e) {
      Notify.dialog(
        context: context,
        type: NotificationType.error,
        title: 'Unknown error',
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
      Random rand = Random.secure();
      int tries = 1000;
      do {
        int random = rand.nextInt(10000) + 1000;
        file = File('$path${Platform.pathSeparator}save-$random.x');
        tries--;
      } while (file.existsSync() && tries > 0);
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
      database.setSource(file, pw);

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
    return Scaffold(
      endDrawer: const HomeNavBar(),
      appBar: AppBar(
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
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
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(title, style: Theme.of(context).textTheme.headlineLarge),
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
                  child: Column(
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
                              shape: MaterialStateProperty.all<
                                  RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                ),
                              ),
                            ),
                            onPressed: () => _selectFile(context),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 25.0, vertical: 2.5),
                              child: Icon(
                                Icons.search,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 35),
                      Consumer<Settings>(
                        builder: (context, settings, child) =>
                            settings.lastOpenedPath.isNotEmpty
                                ? TextButton(
                                    onPressed: () => _openLast(context),
                                    child: Text(
                                      'Open last: ${settings.lastOpenedPath}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
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
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.fontSize,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
