import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:crypto/crypto.dart';

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

    String? keyString = await _storage.read(key: _keyStorageKey);
    if (keyString == null) {
      // Generate new 32-byte (256-bit) key
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

  // Encrypt a file (AES-CTR)
  // Format: [IV (16 bytes)] [Encrypted Content]
  Future<String> encryptFile(File sourceFile, String destPath) async {
    await init();

    final iv = enc.IV.fromSecureRandom(16);

    final destFile = File(destPath);
    // Note: we use direct random access files below

    // Write IV first
    // sink.add(iv.bytes);

    // Encrypt stream
    // AES-CTR doesn't need padding for stream processing normally,
    // but the `encrypt` package's stream API might be tricky with custom chunks.
    // simpler approach for ensuring stability: Read chunks, encrypt, write.

    // We strictly use AES-CTR.
    // To maintain streaming state, usually we need a persistent encrypter state.
    // The `encrypt` package logic relies on `algo.encrypt` which resets for blocks?
    // Actually, `AESMode.ctr` turns a block cipher into a stream cipher.
    // We can just encrypt the whole byte array or chunks if we track the counter.

    // Simplest reliable way with `encrypt` package for large files:
    // It does not expose a streaming API nicely.
    // We will simulate it or just process large chunks (e.g. 1MB) correctly?
    // Be careful: CTR state (counter) must propagate.
    // If the package doesn't support stateful streams, we might have issues.

    // Checked `encrypt` package docs: `Encrypter` doesn't have a stateful `update` method.
    // Ideally we'd use `pointycastle` underlying, but that's complex.

    // WORKAROUND:
    // If we can't easily stream-encrypt with state preservation in this high-level package,
    // We can define our own chunking where chunk_i is encrypted with IV_i
    // where IV_i = InitialIV + (chunk_index * chunk_size/16).
    // This allows random access perfectly!
    // Let's use 1MB chunks.

    int chunkSize = 1024 * 1024; // 1MB

    // Using RandomAccessFile for predictable chunking
    final raf = await sourceFile.open();
    final destRaf = await destFile.open(mode: FileMode.write);

    // Write IV
    await destRaf.writeFrom(iv.bytes);

    int fileLen = await sourceFile.length();
    int readOffset = 0;

    while (readOffset < fileLen) {
      int end = readOffset + chunkSize;
      if (end > fileLen) end = fileLen;

      // Read chunk
      // We need to seek? `raf` moves pointer automatically.
      List<int> bytes = await raf.read(end - readOffset);

      // Calculate IV for this chunk offset
      // Counter is incremented by 1 for every 16 bytes.
      // Offset absolute = readOffset.
      // Counter shift = readOffset / 16.
      // We need to implement IV increment.
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

  // Helper to increment IV (BigEndian 128-bit integer)
  enc.IV _incrementIV(enc.IV startIV, int count) {
    if (count == 0) return startIV;

    // Do manually on bytes
    var bytes = Uint8List.fromList(startIV.bytes);

    // Add count to the bytes (treating as big int)
    int carry = count;
    for (int i = 15; i >= 0; i--) {
      if (carry == 0) break;
      int val = bytes[i] + (carry & 0xFF);
      bytes[i] = val & 0xFF; // keep byte
      carry = (carry >> 8) + (val >> 8); // next carry
    }

    return enc.IV(bytes);
  }

  // Decrypt specific range
  // Returns bytes
  Future<List<int>> decryptRange(File encryptedFile, int start, int end) async {
    await init();

    // First 16 bytes are IV
    if (start < 0) start = 0;

    final raf = await encryptedFile.open();

    // Read IV
    raf.setPosition(0);
    List<int> ivBytes = await raf.read(16);
    final baseIV = enc.IV(Uint8List.fromList(ivBytes));

    // Adjust start to be relative to content (skip 16 bytes header)
    // But arguments `start` and `end` coming from HTTP Range usually refer to the *content*?
    // If the file on disk has 16 bytes header, physical offset is start + 16.

    // Let's assume start/end refer to the 'Clean Content' range.

    // We need to decrypt the block containing 'start'.
    // Block size is 16.
    // AES-CTR: We can decrypt byte-perfect if we line up the counter.

    // Correct Chunk alignment for decryption logic:
    // It's safest to decrypt full 16-byte blocks.

    int contentStart = start;
    int contentEnd = end; // inclusive

    // Align to 16-byte boundary downwards
    int blockAlignedStart = (contentStart ~/ 16) * 16;
    int diff = contentStart - blockAlignedStart;

    int readStart = 16 + blockAlignedStart; // Physical start
    int readLength = (contentEnd - blockAlignedStart) + 1;

    // Make sure we read enough to cover the end, aligned to block?
    // AES-CTR is stream cipher, no padding needed, but `encrypt` package works on blocks effectively or bytes?
    // It works on bytes if padding null, but IV handling is crucial.

    await raf.setPosition(readStart);
    List<int> encryptedBytes = await raf.read(readLength);
    await raf.close();

    // Decrypt
    final chunkIV = _incrementIV(baseIV, blockAlignedStart ~/ 16);
    final encrypter =
        enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));

    // Encrypted bytes -> Decrypt
    // For CTR, encrypt and decrypt are symmetric (XOR).
    final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: chunkIV);

    // Remove the `diff` bytes at start if any
    if (diff > 0) {
      if (diff >= decrypted.length) return [];
      return decrypted.sublist(diff);
    }

    return decrypted;
  }
}
