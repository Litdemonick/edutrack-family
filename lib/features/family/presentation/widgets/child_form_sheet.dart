import 'package:flutter/material.dart';

import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'student_avatar.dart';

// ═══════════════════════════════════════════════════════════════
// FORMULARIO DE HIJO/A — bottom sheet para crear o editar perfil.
// ═══════════════════════════════════════════════════════════════

class ChildFormData {
  final String name;
  final String? grade;
  final int? avatarColor;
  const ChildFormData({required this.name, this.grade, this.avatarColor});
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
  late final _gradeCtrl =
      TextEditingController(text: widget.existing?.grade ?? '');
  late int _colorValue =
      widget.existing?.avatarColor ?? kAvatarColors.first.toARGB32();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ChildFormData(
        name: _nameCtrl.text,
        grade: _gradeCtrl.text.trim().isEmpty ? null : _gradeCtrl.text,
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
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Escribe el nombre'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _gradeCtrl,
                decoration: InputDecoration(
                  labelText: 'Grado (ej. 5° B) — opcional',
                  prefixIcon: const Icon(Icons.school_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
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
                onPressed: _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Text(isEdit ? 'Guardar cambios' : 'Crear perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
