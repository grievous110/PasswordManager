import 'dart:convert';
import 'dart:typed_data';
import 'package:firedart/auth/firebase_auth.dart';
import 'package:firedart/auth/token_store.dart';
import 'package:firedart/firestore/firestore.dart';
import 'package:firedart/firestore/models.dart';
import 'package:firedart/firestore/token_authenticator.dart';
import 'package:passwordmanager/engine/persistance.dart';
import 'package:passwordmanager/engine/implementation/hashing.dart';

import 'keys/access.dart';

/// Subclass of [TokenStore] that manages the tokens acquired by the firebase authentication.
class KeyTokenStorage extends TokenStore {
  final Settings _settings = Settings();

  @override
  Token? read() => _settings.keyToken.isNotEmpty ? Token.fromMap(json.decode(_settings.keyToken)) : null;

  @override
  void write(Token? token) => token != null ? _settings.setKeyToken(json.encode(token?.toMap())) : null;

  @override
  void delete() => _settings.deleteToken();
}

/// Main class for managing the connection to the firebase cloud.
/// Needs to be initialized through a call to the [init] function and can optionally be deactivated.
final class FirebaseConnector {
  static late final bool deactivated;
  static late final Firestore _firestore;
  static late final FirebaseAuth _auth;
  static late CollectionReference _storage;

  String _id = '';

  bool get isLoggedIn => _auth.isSignedIn;

  /// Deletes the id of the last active document
  void invalidate() => _id = '';

  /// Method to initialize the [FirebaseConnector] class. An own [Firestore] and [FirebaseAuth] object are
  /// created for authentication. In addition a reference to the core collection is stored.
  static Future<void> init({bool deactivate = false}) async {
    deactivated = deactivate;
    if(!deactivated) {
      _auth = FirebaseAuth(KeyStore.apiKey, KeyTokenStorage());
      _firestore = Firestore(KeyStore.projectId, authenticator: TokenAuthenticator.from(_auth)?.authenticate);
      _storage = _firestore.collection('ethercrypt-storage');
    }
  }

  /// Performs a login action. Ethercrypt alone is granted access through strict security rules to the cloud data, so the app needs
  /// to be logged in to manipulate data. An exception might be thrown if:
  /// * Failed login
  /// * Internet connection is missing
  Future<void> login() async {
    try {
      if(!isLoggedIn) await _auth.signIn('ethercrypt@access.de', KeyStore.accessCode);
    } catch(e) {
      throw Exception('Could not access cloud storage');
    }
  }

  /// Logs out the app if it was logged in.
  void logout() {
    if(isLoggedIn) {
      _auth.signOut();
      _id = '';
    }
  }

  /// Checks if there is a storage present inside the cloud with the specified name. Return true if it exists, false otherwise.
  /// Cases this method throws exceptions:
  /// * Permission is denied
  /// * Internet connection is missing
  Future<bool> docExists(String name) async {
    try {
      final List<Document> docs = await _storage.where('name', isEqualTo: name).get();
      return docs.isNotEmpty;
    } catch(e) {
      throw Exception('Could not test if document exists');
    }
  }

  /// Checks if the cloud storage with the given name contains the hash value generated by the password, because the plaintext password
  /// is of course not stored inside the cloud. This method also returns false if there is no storage with that name, even if the hash might be correct.
  /// The [Hashing.sha256DoubledHash] method is called to generate these twice hashed values. [_setActiveDocument] was also called if true is returned.
  /// Cases this method throws exceptions:
  /// * Permission is denied
  /// * Internet connection is missing
  Future<bool> verifyPassword({required String name, required String password}) async {
    try {
      final List<Document> docs = await _storage.where('name', isEqualTo: name).get();
      if(docs.isEmpty) return false;
      if(docs.elementAt(0).map['hash'] == Hashing.asString(Hashing.sha256DoubledHash(utf8.encode(password)))) {
        await _setActiveDocument(name);
        return true;
      } else {
        return false;
      }
    } catch(e) {
      throw Exception('Could not verify password');
    }
  }

  /// Sets the [_id] property of this object. This method must be called in order to work with [getData], [editDocument] and [deleteDocument].
  /// Method does nothing if the name does not match any storage.
  /// Cases this method throws exceptions:
  /// * Permission is denied
  /// * Internet connection is missing
  Future<void> _setActiveDocument(String name) async {
    try {
      final List<Document> docs = await _storage.where('name', isEqualTo: name).get();
      if(docs.isNotEmpty) _id = docs.elementAt(0).id;
    } catch(e) {
      throw Exception('Could not set active document');
    }
  }

  /// Creates a Document with the specified properties.
  /// Cases this method throws exceptions:
  /// * Permission is denied
  /// * Internet connection is missing
  Future<void> createDocument({required String name, required Uint8List hash, required String data}) async {
    try {
      final Document doc = await _storage.add({
        'name': name,
        'hash': Hashing.asString(hash),
        'data': data,
      });
      _id = doc.id;
    } catch(e) {
      throw Exception('Could not add new document');
    }
  }

  /// Returns the encrypted data stored at the "data" key in the cloud. Indentifies document via [_id] property.
  /// Cases this method throws exceptions:
  /// * Permission is denied
  /// * Internet connection is missing
  Future<String> getData() async {
    try {
      final Document doc = await _storage.document(_id).get();
      return doc.map['data'];
    } catch(e) {
      throw Exception('Could not access data');
    }
  }

  /// Overwrites the "data" property in the firebase cloud. Indentifies document via [_id] property.
  /// Cases this method throws exceptions:
  /// * Permission is denied
  /// * Internet connection is missing
  Future<void> editDocument({required String newData}) async {
    try {
      await _storage.document(_id).update({
        'data': newData,
      });
    } catch(e) {
      throw Exception('Could not edit document');
    }
  }

  /// Deletes the currently active storage. Indentifies document via [_id] property.
  /// Cases this method throws exceptions:
  /// * Permission is denied
  /// * Internet connection is missing
  Future<void> deleteDocument() async {
    try {
      await _storage.document(_id).delete();
      _id = '';
    } catch(e) {
      _id = '';
      throw Exception('Could not delete document');
    }
  }
}