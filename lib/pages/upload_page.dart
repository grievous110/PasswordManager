import 'package:flutter/material.dart';
import 'package:passwordmanager/engine/persistence.dart';
import 'package:provider/provider.dart';
import 'package:passwordmanager/engine/cloud_connector.dart';
import 'package:passwordmanager/engine/local_database.dart';
import 'package:passwordmanager/pages/other/notifications.dart';

/// Widget that is displayed when a user wants to upload his data from a local file to the firebase cloud.
/// Only needs a name because the password should already be defined through an active local manage session.
class UploadPage extends StatefulWidget {
  const UploadPage({Key? key}) : super(key: key);

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  late bool _canSubmit;
  late TextEditingController _nameController;

  /// Asynchronous method which tries to log into the cloud and create a storage with the given name.
  /// This might fail if permission is denied or there is no internet connection.
  Future<void> _upload(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final FirebaseConnector connector = context.read<FirebaseConnector>();
    final LocalDatabase database = LocalDatabase();
    final Settings settings = context.read<Settings>();

    Notify.showLoading(context: context);
    try {
      await connector.login();
      final bool exists = await connector.docExists(_nameController.text);
      if (exists) {
        throw Exception('Storage with the name "${_nameController.text}" already exists');
      }
      await connector.createDocument(
        name: _nameController.text,
        data: await database.formattedData,
      );
      await settings.setLastOpenedCloudDoc(_nameController.text);

      navigator.pop();
      connector.logout();
      if (!context.mounted) return;
      await Notify.dialog(
        context: context,
        type: NotificationType.notification,
        title: 'Upload success!',
        content: Text(
          'You can now access this storage in online mode under the name "${_nameController.text}" and with the same password.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
      navigator.pop();
    } catch (e) {
      navigator.pop();
      connector.logout();
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
  void initState() {
    _canSubmit = false;
    _nameController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload to cloud',
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
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    children: [
                      TextField(
                        maxLength: 128,
                        controller: _nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Storage name',
                        ),
                        onChanged: (string) => setState(() {
                          _canSubmit = _nameController.text.isNotEmpty;
                        }),
                        onSubmitted: (string) => _canSubmit ? _upload(context) : null,
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50.0),
                          child: TextButton(
                            onPressed: () => _canSubmit ? _upload(context) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'UPLOAD',
                                style: TextStyle(
                                  color: _canSubmit ? null : Colors.blueGrey,
                                  fontSize: Theme.of(context).textTheme.displaySmall!.fontSize,
                                ),
                              ),
                            ),
                          ),
                        ),
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
