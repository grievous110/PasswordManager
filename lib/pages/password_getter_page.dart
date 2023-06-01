import 'package:flutter/material.dart';

/// Widget that provides a password upon beeing popped. The user is asked to type in a password that
/// the is used to encrypt data.
class PasswordGetterPage extends StatefulWidget {
  const PasswordGetterPage({Key? key, required this.path, required this.title})
      : super(key: key);

  final String title;
  final String? path;

  @override
  State<PasswordGetterPage> createState() => _PasswordGetterPageState();
}

/// State checking that passwords can only be submitted if the text input has changed at least once.
class _PasswordGetterPageState extends State<PasswordGetterPage> {
  late bool _isObscured;
  late bool _changes;
  late TextEditingController _pwController;

  @override
  void initState() {
    _isObscured = true;
    _changes = false;
    _pwController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineLarge,
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
        padding: const EdgeInsets.all(35.0),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Text(
                      widget.path ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 10.0,
                    ),
                    TextField(
                      obscureText: _isObscured,
                      maxLength: 32,
                      autofocus: true,
                      controller: _pwController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isObscured = !_isObscured;
                            });
                          },
                          icon: Icon(_isObscured
                              ? Icons.visibility_off
                              : Icons.visibility),
                        ),
                      ),
                      onChanged: !_changes
                          ? (string) => setState(() {
                                _changes = true;
                              })
                          : null,
                      onSubmitted: (string) => _pwController.text.isNotEmpty
                          ? Navigator.pop(context, string)
                          : null,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50.0),
                        child: TextButton(
                          onPressed: () => _pwController.text.isNotEmpty
                              ? Navigator.pop(context, _pwController.text)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              'SUBMIT',
                              style: TextStyle(
                                color: _pwController.text.isEmpty
                                    ? Colors.blueGrey
                                    : Theme.of(context).colorScheme.primary,
                                fontSize: 16,
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
    );
  }
}
