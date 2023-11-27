import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:passwordmanager/engine/cryptography/datatypes.dart';

/// Cryptographic utility service class
final class CryptographicService {

  /// Appends randomly generated bytes with [CryptographicService.randomBytes] to the given list to match a multiple of the provided block size.
  /// Useful for some cryptographic algorithms which need a specific block length as input.
  static Uint8List expand(Uint8List data, int blocksize, {int min = 0x00, int max = 0xff}) {
    if(data.isEmpty) {
      return randomBytes(blocksize);
    } else {
      final int diff = (blocksize - (data.length % blocksize)) % blocksize;
      final Uint8List filler = randomBytes(diff, min: min, max: max);
      return Uint8List.fromList([...data, ...filler]);
    }
  }

  /// Appends randomly chosen bytes from given list to the initial list to match a multiple of the provided block size.
  /// Useful for some cryptographic algorithms which need a specific block length as input.
  static Uint8List expandWithValues(Uint8List data, int blocksize, List<int> values) {
    final Random random = Random.secure();
    if(data.isEmpty) {
      return Uint8List.fromList(List.generate(blocksize, (index) => values[random.nextInt(values.length)] & 0xff));
    } else {
      final int diff = (blocksize - (data.length % blocksize)) % blocksize;
      final Uint8List filler = Uint8List.fromList(List.generate(diff, (index) => values[random.nextInt(values.length)] & 0xff));
      return Uint8List.fromList([...data, ...filler]);
    }
  }

  /// Returns secure and randomly generated bytes
  static Uint8List randomBytes(final int length, {int min = 0x00, int max = 0xff}) {
    if(min < 0x00 || max > 0xff || min > max) throw Exception('Not allowed random byte constraints');
    final Random random = Random.secure();
    return Uint8List.fromList(List.generate(length, (index) => random.nextInt(max+1-min) + min));
  }

  /// Creates a 32 bytes key based on the provided password. See [Key] class for details.
  static Key createAES256Key({required String password}) => Key.createSecure(password, 32);

  /// Recreates a 32 bytes key based on the provided password and salt. See [Key] class for details.
  static Key recreateAES256Key({required String password, required Uint8List salt}) {
    return Key.recreate(password, salt, 32);
  }

  /// Create a HMAC with SHA-256 code. Useful for verifying data integrity.
  static Uint8List verificationCodeFrom(Key key, Uint8List data) {
    final HMac hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key.bytes));
    final Uint8List verificationCode = hmac.process(data);
    return verificationCode;
  }

  /// Returns SHA-256 hash
  static Uint8List sha256(Uint8List data) {
    return SHA256Digest().process(data);
  }
}