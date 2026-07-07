import 'dart:async';

// ═══════════════════════════════════════════════════════════════
// POLLING CURSOR STREAM — sustituto de .snapshots() para Windows/
// Linux (Firestore REST no tiene streaming nativo simple). Reusa
// la misma idea de cursor (updatedAfter) que ya usa
// core/services/sync_service.dart para el pull incremental — la
// diferencia es que aquí el cursor vive en memoria por
// suscripción, para alimentar la UX de "actualización casi
// instantánea", no la corrección de datos (esa la garantiza el
// pull con cursor persistido en SQLite).
// ═══════════════════════════════════════════════════════════════

/// [fetchAll] debe devolver el conjunto COMPLETO de filas vigentes
/// (no solo las cambiadas) en cada llamada — a diferencia del pull
/// de sync_service.dart, aquí no hay una capa de merge en el
/// llamador, así que cada tick reemplaza el snapshot completo.
class PollingStream<T> {
  final Future<List<T>> Function() fetchAll;
  final Duration interval;

  PollingStream({required this.fetchAll, required this.interval});

  Stream<List<T>> watch() {
    late final StreamController<List<T>> controller;
    Timer? timer;

    Future<void> tick() async {
      try {
        final rows = await fetchAll();
        if (!controller.isClosed) controller.add(rows);
      } catch (_) {
        // Falla silenciosa en un tick: se reintenta en el próximo.
        // El offline-first ya tolera datos desactualizados.
      }
    }

    controller = StreamController<List<T>>.broadcast(
      onListen: () {
        tick();
        timer = Timer.periodic(interval, (_) => tick());
      },
      onCancel: () {
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}

/// Variante para un solo documento (ej. watchCurrent/watchStudent).
class PollingDocStream<T> {
  final Future<T> Function() fetch;
  final Duration interval;

  PollingDocStream({required this.fetch, required this.interval});

  Stream<T> watch() {
    late final StreamController<T> controller;
    Timer? timer;

    Future<void> tick() async {
      try {
        final row = await fetch();
        if (!controller.isClosed) controller.add(row);
      } catch (_) {}
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        tick();
        timer = Timer.periodic(interval, (_) => tick());
      },
      onCancel: () {
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}
