import 'package:passwordmanager/engine/local_database.dart';

/// Core class that holds information about an account.
/// Implements the [Comparable] interface. The natural order of
/// instances is the lowercase alphabetical order.
final class Account implements Comparable<Account> {
  static const String _noEntry = 'none';

  static int _idCounter = 0;
  final int id;

  late String _tag;

  late String _name;
  late String _info;
  late String _email;
  late String _password;

  Account({String? tag, String? name, String? info, String? email, String? password}) : id = ++_idCounter {
    setTag = tag;
    setName = name;
    setInfo = info;
    setEmail = email;
    setPassword = password;
  }

  String get tag => _tag;
  String get name => _name;
  String get info => _info;
  String get email => _email;
  String get password => _password;

  set setTag(String? string) => _tag = _nullSaveValue(string);
  set setName(String? string) => _name = _nullSaveValue(string);
  set setInfo(String? string) => _info = _nullSaveValue(string);
  set setEmail(String? string) => _email = _nullSaveValue(string);
  set setPassword(String? string) => _password = _nullSaveValue(string);

  String _nullSaveValue(String? string) => (string ??= Account._noEntry).isEmpty ? Account._noEntry : string;

  @override
  int compareTo(Account other) {
    return name.toLowerCase().compareTo(other.name.toLowerCase());
  }

  /// Returns a format that can be easily read from a string with a RegEx.
  @override
  String toString() {
    const String c = LocalDatabase.disallowedCharacter;
    return '$c$tag$c$name$c$info$c$email$c$password$c';
  }
}
