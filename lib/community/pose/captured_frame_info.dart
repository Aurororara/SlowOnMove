import 'dart:typed_data';

/// Native WebRTC returns PNG on iOS but JPEG on Android (even for .png paths).
({int width, int height, String extension}) capturedFrameInfo(Uint8List bytes) {
  final header = ByteData.sublistView(bytes);
  if (bytes.length >= 24 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[12] == 73 &&
      bytes[13] == 72 &&
      bytes[14] == 68 &&
      bytes[15] == 82) {
    return _checked(header.getUint32(16), header.getUint32(20), 'png');
  }
  if (bytes.length >= 4 && bytes[0] == 255 && bytes[1] == 216) {
    var offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset++] != 255) break;
      while (offset < bytes.length && bytes[offset] == 255) {
        offset++;
      }
      if (offset >= bytes.length) break;
      final marker = bytes[offset++];
      if (marker == 217 || marker == 218) break;
      if (marker == 1 || (marker >= 208 && marker <= 216)) continue;
      if (offset + 2 > bytes.length) break;
      final length = header.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) break;
      if ([192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207]
          .contains(marker)) {
        if (length < 8) break;
        return _checked(
            header.getUint16(offset + 5), header.getUint16(offset + 3), 'jpg');
      }
      offset += length;
    }
  }
  throw const FormatException('Unsupported captured frame');
}

({int width, int height, String extension}) _checked(
    int width, int height, String extension) {
  if (width == 0 || height == 0 || width > 4096 || height > 4096) {
    throw const FormatException('Invalid captured dimensions');
  }
  return (width: width, height: height, extension: extension);
}
