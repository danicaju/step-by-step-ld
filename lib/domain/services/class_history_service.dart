import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../math_engine/models/step_resolution.dart';

/// Modelo de un ejercicio resuelto en el historial de la sesión de clase
class ClassHistoryEntry {
  final String id;
  final DateTime timestamp;
  final String modeName;
  final String studentTag;
  final bool isFavorite;
  final StepByStepResolution resolution;
  final String? rawExpression;
  final int? calculatorMode;

  const ClassHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.modeName,
    this.studentTag = 'General',
    this.isFavorite = false,
    required this.resolution,
    this.rawExpression,
    this.calculatorMode,
  });

  ClassHistoryEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? modeName,
    String? studentTag,
    bool? isFavorite,
    StepByStepResolution? resolution,
    String? rawExpression,
    int? calculatorMode,
  }) {
    return ClassHistoryEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      modeName: modeName ?? this.modeName,
      studentTag: studentTag ?? this.studentTag,
      isFavorite: isFavorite ?? this.isFavorite,
      resolution: resolution ?? this.resolution,
      rawExpression: rawExpression ?? this.rawExpression,
      calculatorMode: calculatorMode ?? this.calculatorMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'modeName': modeName,
        'studentTag': studentTag,
        'isFavorite': isFavorite,
        'resolution': resolution.toJson(),
        if (rawExpression != null) 'rawExpression': rawExpression,
        if (calculatorMode != null) 'calculatorMode': calculatorMode,
      };

  factory ClassHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ClassHistoryEntry(
        id: json['id'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        modeName: json['modeName'] as String? ?? 'Aritmética',
        studentTag: json['studentTag'] as String? ?? 'General',
        isFavorite: json['isFavorite'] as bool? ?? false,
        resolution: StepByStepResolution.fromJson(
            json['resolution'] as Map<String, dynamic>? ?? {}),
        rawExpression: json['rawExpression'] as String?,
        calculatorMode: json['calculatorMode'] as int?,
      );
}

/// Servicio de persistencia y exportación del historial de clase
class ClassHistoryService {
  static const String _storageKey = 'casio_class_history_v1';
  static const int maxStoredEntries = 100;

  /// Obtiene todos los ejercicios del historial ordenados del más reciente al más antiguo
  Future<List<ClassHistoryEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey) ?? [];

    final List<ClassHistoryEntry> entries = [];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        entries.add(ClassHistoryEntry.fromJson(decoded));
      } catch (_) {}
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Añade un nuevo ejercicio resuelto al historial
  Future<void> addEntry(ClassHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getEntries();

    // Evitamos duplicar idéntico ejercicio consecutivo si se pulsa = varias veces seguidas
    if (current.isNotEmpty &&
        current.first.resolution.originalInputLatex ==
            entry.resolution.originalInputLatex &&
        current.first.modeName == entry.modeName &&
        DateTime.now().difference(current.first.timestamp).inSeconds < 3) {
      return;
    }

    current.insert(0, entry);
    if (current.length > maxStoredEntries) {
      current.removeRange(maxStoredEntries, current.length);
    }

    final rawList = current.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, rawList);
  }

  /// Alterna el estado de favorito / examen de un ejercicio
  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getEntries();

    final index = current.indexWhere((e) => e.id == id);
    if (index != -1) {
      final updated = current[index].copyWith(
        isFavorite: !current[index].isFavorite,
      );
      current[index] = updated;
      final rawList = current.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_storageKey, rawList);
    }
  }

  /// Elimina un ejercicio específico por su ID
  Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getEntries();

    current.removeWhere((e) => e.id == id);
    final rawList = current.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, rawList);
  }

  /// Limpia todo el historial de la calculadora
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Cuenta el número de ejercicios resueltos en el día de hoy
  Future<int> getTodayEntriesCount() async {
    final entries = await getEntries();
    final now = DateTime.now();
    return entries.where((e) =>
        e.timestamp.year == now.year &&
        e.timestamp.month == now.month &&
        e.timestamp.day == now.day).length;
  }

  /// Genera un resumen completo en código LaTeX (.tex) con todos los ejercicios seleccionados
  String generateClassTexSummary(List<ClassHistoryEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln(r'\documentclass[12pt,a4paper]{article}');
    buffer.writeln(r'\usepackage[utf8]{inputenc}');
    buffer.writeln(r'\usepackage[spanish]{babel}');
    buffer.writeln(r'\usepackage{amsmath,amssymb}');
    buffer.writeln(r'\usepackage{xcolor}');
    buffer.writeln(r'\usepackage{geometry}');
    buffer.writeln(r'\geometry{margin=2cm}');
    buffer.writeln(r'\usepackage{tcolorbox}');
    buffer.writeln();
    buffer.writeln(r'\title{\textbf{Resumen de Sesión de Clase: Calculadora Casio Tutor}}');
    buffer.writeln(r'\author{Apuntes de Matemáticas ESO / Bachillerato}');
    buffer.writeln(r'\date{\today}');
    buffer.writeln();
    buffer.writeln(r'\begin{document}');
    buffer.writeln(r'\maketitle');
    buffer.writeln();

    if (entries.isEmpty) {
      buffer.writeln(r'\textit{No hay ejercicios registrados en esta sesión.}');
    } else {
      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        final res = e.resolution;
        final starTag = e.isFavorite ? r' \textcolor{red}{\star \text{ (Pregunta Tipica)}}' : '';

        buffer.writeln(
            '\\begin{tcolorbox}[colback=blue!5!white,colframe=blue!75!black,title=\\textbf{Ejercicio ${i + 1}: ${e.modeName} - [${e.studentTag}]$starTag}]');
        buffer.writeln(r'\textbf{Problema original:}');
        buffer.writeln('\\[ ${res.originalInputLatex} \\]');
        buffer.writeln(r'\vspace{4pt}');
        buffer.writeln(r'\textbf{Resolución paso a paso:}');
        buffer.writeln(r'\begin{enumerate}');

        for (final s in res.steps) {
          buffer.writeln('  \\item \\textbf{${s.shortTitle}:}');
          buffer.writeln('  \\[ ${s.latexExpression} \\]');
          buffer.writeln('  \\textit{${s.pedagogicalNote}}');
          if (s.warningTrick != null) {
            buffer.writeln(
                '  \\par\\textcolor{red}{\\textbf{Atencion:} ${s.warningTrick!}}');
          }
          buffer.writeln();
        }

        buffer.writeln(r'\end{enumerate}');
        buffer.writeln(r'\textbf{Resultado final exacto:}');
        buffer.writeln(
            '\\[ \\mathbf{${res.exactResultLatex}} \\quad \\text{(Aprox: } ${res.decimalApproxLatex}\\text{)} \\]');
        buffer.writeln(r'\end{tcolorbox}');
        buffer.writeln(r'\vspace{10pt}');
      }
    }

    buffer.writeln(r'\end{document}');
    return buffer.toString();
  }
}
