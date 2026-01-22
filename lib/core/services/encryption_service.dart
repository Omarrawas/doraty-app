import 'dart:io' show File, FileMode;
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  final _keyStorageKey = 'video_encryption_key';
  enc.Key? _encryptionKey;

  // Initialize: Load or create key
  Future<void> init() async {
    if (_encryptionKey != null) return;

    if (kIsWeb) {
      // On Web, secure storage might use LocalStorage. For consistency:
      String? keyString = await _storage.read(key: _keyStorageKey);
      if (keyString == null) {
        final key = enc.Key.fromSecureRandom(32);
        await _storage.write(key: _keyStorageKey, value: key.base64);
        _encryptionKey = key;
      } else {
        _encryptionKey = enc.Key.fromBase64(keyString);
      }
      return;
    }

    String? keyString = await _storage.read(key: _keyStorageKey);
    if (keyString == null) {
      final key = enc.Key.fromSecureRandom(32);
      await _storage.write(key: _keyStorageKey, value: key.base64);
      _encryptionKey = key;
    } else {
      _encryptionKey = enc.Key.fromBase64(keyString);
    }
  }

  enc.Key get key {
    if (_encryptionKey == null) {
      throw Exception('EncryptionService not initialized. Call init() first.');
    }
    return _encryptionKey!;
  }

  // Encrypt bytes (Platform independent for small/medium files)
  Future<Uint8List> encryptBytes(Uint8List source) async {
    await init();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter =
        enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
    final encrypted = encrypter.encryptBytes(source, iv: iv);
    
    final result = BytesBuilder();
    result.add(iv.bytes);
    result.add(encrypted.bytes);
    return result.toBytes();
  }

  // Decrypt bytes
  Future<Uint8List> decryptBytes(Uint8List encryptedData) async {
    await init();
    if (encryptedData.length < 16) throw Exception('Invalid encrypted data');
    
    final iv = enc.IV(encryptedData.sublist(0, 16));
    final content = encryptedData.sublist(16);
    
    final encrypter =
        enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(content), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  // Encrypt a file (Native only)
  Future<String> encryptFile(File sourceFile, String destPath) async {
    if (kIsWeb) throw UnsupportedError('encryptFile is not supported on Web');
    await init();

    final iv = enc.IV.fromSecureRandom(16);
    final destFile = File(destPath);
    int chunkSize = 1024 * 1024; // 1MB

    final raf = await sourceFile.open();
    final destRaf = await destFile.open(mode: FileMode.write);

    await destRaf.writeFrom(iv.bytes);

    int fileLen = await sourceFile.length();
    int readOffset = 0;

    while (readOffset < fileLen) {
      int end = readOffset + chunkSize;
      if (end > fileLen) end = fileLen;

      List<int> bytes = await raf.read(end - readOffset);
      final chunkIV = _incrementIV(iv, readOffset ~/ 16);

      final chunkEncrypter =
          enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
      final encryptedChunk = chunkEncrypter.encryptBytes(bytes, iv: chunkIV);

      await destRaf.writeFrom(encryptedChunk.bytes);
      readOffset = end;
    }

    await raf.close();
    await destRaf.close();
    return destPath;
  }

  enc.IV _incrementIV(enc.IV startIV, int count) {
    if (count == 0) return startIV;
    var bytes = Uint8List.fromList(startIV.bytes);
    int carry = count;
    for (int i = 15; i >= 0; i--) {
      if (carry == 0) break;
      int val = bytes[i] + (carry & 0xFF);
      bytes[i] = val & 0xFF;
      carry = (carry >> 8) + (val >> 8);
    }
    return enc.IV(bytes);
  }

  // Decrypt specific range (Native only)
  Future<List<int>> decryptRange(File encryptedFile, int start, int end) async {
    if (kIsWeb) throw UnsupportedError('decryptRange is not supported on Web');
    await init();

    if (start < 0) start = 0;
    final raf = await encryptedFile.open();
    raf.setPosition(0);
    List<int> ivBytes = await raf.read(16);
    final baseIV = enc.IV(Uint8List.fromList(ivBytes));

    int contentStart = start;
    int contentEnd = end;
    int blockAlignedStart = (contentStart ~/ 16) * 16;
    int diff = contentStart - blockAlignedStart;

    int readStart = 16 + blockAlignedStart;
    int readLength = (contentEnd - blockAlignedStart) + 1;

    await raf.setPosition(readStart);
    List<int> encryptedBytes = await raf.read(readLength);
    await raf.close();

    final chunkIV = _incrementIV(baseIV, blockAlignedStart ~/ 16);
    final encrypter =
        enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));

    final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: chunkIV);

    if (diff > 0) {
      if (diff >= decrypted.length) return [];
      return decrypted.sublist(diff);
    }
    return decrypted;
  }
}

