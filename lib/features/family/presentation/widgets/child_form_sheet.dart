import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/utils/input_sanitizer.dart';
import 'package:edutrack_family/features/family/data/family_repository.dart';
import 'student_avatar.dart';

// Letras (incl. acentuadas/ñ), espacios, apóstrofes y guiones — cubre
// nombres reales en español sin permitir números/símbolos/emoji.
final RegExp _namePattern = RegExp(r"^[a-zA-ZÀ-ÿ' -]+$");

// Solo dígitos y guiones — ej. cédula panameña "8-888-8888". Sin
// espacios ni otros símbolos.
final RegExp _cedulaCharPattern = RegExp(r'^[0-9-]+$');

// Estructura real: provincia-tomo-partida (ej. "8-888-8888"). El
// primer grupo es el código de provincia (1-13, cualquier dígito de
// 1-2 cifras vale — no hay una regla que excluya a alguno de ellos,
// con Chiriquí = 4 siendo un código tan válido como cualquier otro).
// Esto es lo que rechaza algo como "33333" (puros dígitos sin la
// estructura de guiones) sin bloquear cédulas reales.
final RegExp _cedulaFormatPattern = RegExp(r'^\d{1,2}-\d{2,4}-\d{3,6}$');

// Selector en vez de campo libre: evita valores inventados/mal escritos.
const List<String> _gradeOptions = [
  'Maternal', 'Pre-Kínder', 'Kínder',
  '1°', '2°', '3°', '4°', '5°', '6°',
  '7°', '8°', '9°',
  '10°', '11°', '12°',
];
const List<String> _sectionOptions = ['A', 'B', 'C', 'D', 'E', 'F'];

// ═══════════════════════════════════════════════════════════════
// FORMULARIO DE HIJO/A — bottom sheet para crear o editar perfil.
// ═══════════════════════════════════════════════════════════════

class ChildFormData {
  final String name;
  final String cedula;
  final String? grade;
  final int? avatarColor;
  const ChildFormData({
    required this.name,
    required this.cedula,
    this.grade,
    this.avatarColor,
  });
}

Future<ChildFormData?> showChildFormSheet(
  BuildContext context, {
  StudentProfile? existing,
}) {
  return showModalBottomSheet<ChildFormData>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ChildFormSheet(existing: existing),
  );
}

class _ChildFormSheet extends StatefulWidget {
  final StudentProfile? existing;
  const _ChildFormSheet({this.existing});

  @override
  State<_ChildFormSheet> createState() => _ChildFormSheetState();
}

class _ChildFormSheetState extends State<_ChildFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _cedulaCtrl =
      TextEditingController(text: widget.existing?.cedula ?? '');
  late int _colorValue =
      widget.existing?.avatarColor ?? kAvatarColors.first.toARGB32();
  String? _selectedGrade;
  String? _selectedSection;
  String? _cedulaDuplicateError;
  bool _checkingCedula = false;

  @override
  void initState() {
    super.initState();
    // El valor viejo era texto libre (ej. "5° B") — si no coincide con
    // ninguna opción del selector, se deja sin elegir en vez de forzar
    // un valor inválido.
    final existingGrade = widget.existing?.grade?.trim();
    if (existingGrade != null && existingGrade.isNotEmpty) {
      final parts = existingGrade.split(RegExp(r'\s+'));
      _selectedGrade = _gradeOptions.contains(parts.first) ? parts.first : null;
      if (parts.length > 1 && _sectionOptions.contains(parts[1].toUpperCase())) {
        _selectedSection = parts[1].toUpperCase();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cedulaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cedula = _cedulaCtrl.text.trim();
    setState(() => _checkingCedula = true);
    final error = await FamilyRepository.instance.checkCedulaAvailable(
      cedula: cedula,
      excludeStudentId: widget.existing?.id,
    );
    if (!mounted) return;
    setState(() {
      _checkingCedula = false;
      _cedulaDuplicateError = error;
    });
    if (error != null) {
      _formKey.currentState!.validate();
      return;
    }

    final name = InputSanitizer.clean(_nameCtrl.text);
    final grade = [
      if (_selectedGrade != null) _selectedGrade,
      if (_selectedSection != null) _selectedSection,
    ].join(' ');
    if (!mounted) return;
    Navigator.pop(
      context,
      ChildFormData(
        name: name,
        cedula: cedula,
        grade: grade.isEmpty ? null : grade,
        avatarColor: _colorValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: CenteredConstrained(
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEdit ? 'Editar perfil' : 'Nuevo hijo/a',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameCtrl,
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                validator: (v) {
                  final cleaned = InputSanitizer.clean(v ?? '');
                  if (cleaned.isEmpty) return 'Escribe el nombre';
                  if (cleaned.length < 2) return 'Nombre muy corto';
                  if (cleaned.length > 80) return 'Máximo 80 caracteres';
                  if (!_namePattern.hasMatch(cleaned)) {
                    return 'Solo letras, espacios, apóstrofes y guiones';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cedulaCtrl,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                ],
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: 'Cédula',
                  hintText: 'Ej. 8-888-8888',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: _checkingCedula
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (_) {
                  if (_cedulaDuplicateError != null) {
                    setState(() => _cedulaDuplicateError = null);
                  }
                },
                validator: (v) {
                  final cleaned = (v ?? '').trim();
                  if (cleaned.isEmpty) return 'La cédula es obligatoria';
                  if (!_cedulaCharPattern.hasMatch(cleaned)) {
                    return 'Solo números y guiones';
                  }
                  if (!_cedulaFormatPattern.hasMatch(cleaned)) {
                    return cleaned.length < 7
                        ? 'Cédula muy corta'
                        : 'Formato inválido — ej. 8-888-8888';
                  }
                  if (_cedulaDuplicateError != null) {
                    return _cedulaDuplicateError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGrade,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Grado — opcional',
                        prefixIcon: const Icon(Icons.school_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                            child: Text('Sin especificar')),
                        for (final g in _gradeOptions)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (v) => setState(() => _selectedGrade = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSection,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Sección',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        const DropdownMenuItem<String>(child: Text('—')),
                        for (final s in _sectionOptions)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _selectedSection = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Color del avatar'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final color in kAvatarColors)
                    InkWell(
                      onTap: () =>
                          setState(() => _colorValue = color.toARGB32()),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _colorValue == color.toARGB32()
                              ? Border.all(width: 3, color: Colors.black87)
                              : null,
                        ),
                        child: _colorValue == color.toARGB32()
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 22)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _checkingCedula ? null : _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: _checkingCedula
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? 'Guardar cambios' : 'Crear perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
