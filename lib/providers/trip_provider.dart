import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/trip_model.dart';
import '../services/local_db_service.dart';
import '../services/firestore_service.dart';

class TripProvider extends ChangeNotifier {
  final LocalDbService   _local;
  final FirestoreService _remote;
  static const _uuid = Uuid();

  TripProvider(this._local, this._remote);

  // ── الرحلات ──────────────────────────────────────────────────────────────
  List<TripModel> get allTrips => _local.getAllTrips();

  Future<TripModel> addTrip({
    required String name,
    required String description,
    required String dateKey,
    required double price,
    required String createdBy,
  }) async {
    final now  = DateTime.now();
    final trip = TripModel(
      id:          _uuid.v4(),
      name:        name.trim(),
      description: description.trim(),
      dateKey:     dateKey,
      price:       price,
      createdBy:   createdBy,
      createdAt:   now,
      updatedAt:   now,
    );
    // احفظ محلياً أولاً (فوري للـ UI)
    await _local.saveTrip(trip);
    notifyListeners();
    // ارفع لـ Firestore (يوصل للخدام التانيين عبر real-time listener)
    try { await _remote.pushTrip(trip); } catch (_) {}
    return trip;
  }

  Future<void> updateTrip(TripModel trip) async {
    final updated = trip.copyWith(updatedAt: DateTime.now());
    await _local.saveTrip(updated);
    notifyListeners();
    try { await _remote.pushTrip(updated); } catch (_) {}
  }

  /// حذف نهائي للرحلة وكل حجوزاتها (محلياً + Firestore)
  Future<void> deleteTrip(String tripId) async {
    await _local.hardDeleteTrip(tripId);
    notifyListeners();
    try { await _remote.deleteTrip(tripId); } catch (_) {}
  }

  // ── الحجوزات ──────────────────────────────────────────────────────────────
  List<TripBooking> getBookingsForTrip(String tripId) =>
      _local.getBookingsForTrip(tripId);

  bool isStudentBooked(String tripId, String studentId) =>
      _local.isStudentBooked(tripId, studentId);

  Future<void> addBooking({
    required String tripId,
    required String studentId,
    required double paidAmount,
    required String addedBy,
  }) async {
    final now     = DateTime.now();
    final booking = TripBooking(
      id:          TripBooking.buildId(tripId, studentId),
      tripId:      tripId,
      studentId:   studentId,
      paidAmount:  paidAmount,
      addedBy:     addedBy,
      createdAt:   now,
      updatedAt:   now,
    );
    await _local.saveBooking(booking);
    notifyListeners();
    try { await _remote.pushBooking(booking); } catch (_) {}
  }

  Future<void> updatePaidAmount(String bookingId, double newAmount) async {
    final b = _local.getBooking(bookingId);
    if (b == null) return;
    final updated = b.copyWith(paidAmount: newAmount, updatedAt: DateTime.now());
    await _local.saveBooking(updated);
    notifyListeners();
    try { await _remote.pushBooking(updated); } catch (_) {}
  }

  /// حذف نهائي للحجز
  Future<void> deleteBooking(String bookingId) async {
    await _local.hardDeleteBooking(bookingId);
    notifyListeners();
    try { await _remote.deleteBooking(bookingId); } catch (_) {}
  }

  // ── إحصائيات الرحلة ──────────────────────────────────────────────────────
  ({int bookings, double totalCollected, double totalExpected}) tripStats(
      String tripId) {
    final trip     = _local.getTrip(tripId);
    final bookings = getBookingsForTrip(tripId);
    final totalCollected =
        bookings.fold<double>(0, (s, b) => s + b.paidAmount);
    final totalExpected =
        trip != null ? bookings.length * trip.price : 0.0;
    return (
      bookings:       bookings.length,
      totalCollected: totalCollected,
      totalExpected:  totalExpected,
    );
  }
}
