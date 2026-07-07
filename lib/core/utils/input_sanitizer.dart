// ===================================================================
// INPUT SANITIZER -- EduTrack Family
// Limpia texto pegado desde el portapapeles antes de usarlo (correo,
// contrasena, nombre): recorta espacios sobrantes y quita caracteres
// invisibles que se cuelan al copiar de WhatsApp/gestores de
// contrasenas/notas (espacios de ancho cero, BOM, espacio de
// no-separacion) -- sin esto, un correo o contrasena "correcto a
// simple vista" puede fallar el login por un caracter invisible de mas.
//
// Se itera por code point (no regex) para no depender de escribir
// caracteres invisibles literales en este archivo fuente.
// ===================================================================

class InputSanitizer {
  InputSanitizer._();

  static const int _zeroWidthSpace = 0x200B;
  static const int _zeroWidthNonJoiner = 0x200C;
  static const int _zeroWidthJoiner = 0x200D;
  static const int _bom = 0xFEFF;
  static const int _nbsp = 0x00A0;
  static const int _regularSpace = 0x0020;

  static bool _isZeroWidth(int codePoint) =>
      codePoint == _zeroWidthSpace ||
      codePoint == _zeroWidthNonJoiner ||
      codePoint == _zeroWidthJoiner ||
      codePoint == _bom;

  /// Recorta espacios al inicio/fin y quita caracteres invisibles que
  /// se cuelan al copiar y pegar.
  static String clean(String input) {
    final buffer = StringBuffer();
    for (final codePoint in input.runes) {
      if (_isZeroWidth(codePoint)) continue;
      buffer.writeCharCode(codePoint == _nbsp ? _regularSpace : codePoint);
    }
    return buffer.toString().trim();
  }
}
