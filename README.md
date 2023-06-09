# PasswordManager Copyright (c) 2023 Joel Lutz

This is a small app that allows quick and easy management for accounts with emails, passwords... etc. locally (and in a cloud storage since 1.1.0).
The encryption method that is used is AES-256 with keys generated by the SHA-256 hashing algorithm with the UTF-8 encoded password as input.
The cloud storage enforces strict security rules, only allowing this app access. For verification purposes the hashed key value is stored in the cloud storage, with the name and data.

Note:
Compiling and running this app won't work since the file .../lib/engine/keys/access.dart is missing. Normally this grants only this app access to the cloud storage.
However you can use your custom project-id, api-key and password for your own firebase cloud storage.

Create access.dart file content like this:
final class KeyStore {
  static const String apiKey = "your-api-key";
  static const String projectId = "your-project-id";
  static const String accessCode = "your-password"; // You need to have an account that allows access to "ethercrypt@access.de"
}
