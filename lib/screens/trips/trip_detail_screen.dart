import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../models/student_model.dart';
import '../../core/constants/app_colors.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final tripProv  = context.watch<TripProvider>();
    final allTrips  = tripProv.allTrips;
    final allStudents = context.watch<StudentProvider>().allStudents;
    final bookings  = tripProv.getBookingsForTrip(widget.tripId);
    final bookedIds = {for (final b in bookings) b.studentId};
    final isAdmin   = context.watch<AuthProvider>().isAdmin;
    final user      = context.read<AuthProvider>().currentUser;
    final stats     = tripProv.tripStats(widget.tripId);

    final tripIndex = allTrips.indexWhere((t) => t.id == widget.tripId);
    if (tripIndex == -1) {
      return const Scaffold(body: Center(child: Text('الرحلة غير موجودة')));
    }
    final tripData = allTrips[tripIndex];

    final filtered = _search.trim().isEmpty
        ? allStudents
        : allStudents.where((s) =>
            s.firstName.toLowerCase().contains(_search.toLowerCase()) ||
            s.fullName.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tripData.name)),
      body: Column(
        children: [
          // ── ملخص الرحلة ──────────────────────────────────────────────────
          Container(
            color: AppColors.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (tripData.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(tripData.description,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('📅 التاريخ', tripData.dateKey),
                    _stat('💰 السعر', '${tripData.price.toStringAsFixed(0)} جنيه'),
                    _stat('👥 الحجوزات', '${stats.bookings}'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: stats.totalExpected > 0
                      ? (stats.totalCollected / stats.totalExpected).clamp(0.0, 1.0)
                      : 0,
                  backgroundColor: AppColors.divider,
                  color: AppColors.present,
                  minHeight: 6,
                ),
                const SizedBox(height: 4),
                Text(
                  'تحصّل ${stats.totalCollected.toStringAsFixed(0)} من ${stats.totalExpected.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // ── بحث ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث عن شاب...',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // ── قائمة الشباب ─────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('مفيش نتائج',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final student = filtered[i];
                      final booked  = bookedIds.contains(student.id);
                      final booking = booked
                          ? bookings.firstWhere((b) => b.studentId == student.id)
                          : null;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: booked ? AppColors.present : AppColors.divider,
                            child: Icon(
                              booked ? Icons.check_rounded : Icons.person_outline,
                              color: booked ? Colors.white : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          title: Text(student.fullName),
                          subtitle: booked
                              ? Text(
                                  'دفع: ${booking!.paidAmount.toStringAsFixed(0)} / ${tripData.price.toStringAsFixed(0)} جنيه',
                                  style: TextStyle(
                                    color: booking.paidAmount >= tripData.price
                                        ? AppColors.present
                                        : AppColors.warning,
                                  ),
                                )
                              : const Text('لم يحجز'),
                          trailing: booked
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'تعديل المبلغ المدفوع',
                                      onPressed: () => _editPaid(context, booking!, tripData, tripProv),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline,
                                          color: AppColors.absent, size: 20),
                                      tooltip: 'إلغاء الحجز',
                                      onPressed: () => _cancelBooking(
                                          context, booking!.id, student.firstName, tripProv),
                                    ),
                                  ],
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: AppColors.primary),
                                  tooltip: 'إضافة للرحلة',
                                  onPressed: () => _addBooking(
                                      context, widget.tripId, student,
                                      tripData.price, user?.name ?? '', tripProv),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ],
  );

  Future<void> _addBooking(BuildContext context, String tripId, StudentModel student,
      double tripPrice, String addedBy, TripProvider tripProv) async {
    final paidCtrl = TextEditingController(text: tripPrice.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حجز ${student.firstName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سعر الرحلة: ${tripPrice.toStringAsFixed(0)} جنيه'),
            const SizedBox(height: 12),
            TextField(
              controller: paidCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع (جنيه)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final paid = double.tryParse(paidCtrl.text.trim()) ?? 0;
    await tripProv.addBooking(
        tripId: tripId, studentId: student.id,
        paidAmount: paid, addedBy: addedBy);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة ${student.firstName} للرحلة')));
    }
  }

  Future<void> _editPaid(BuildContext context, TripBooking booking,
      TripModel trip, TripProvider tripProv) async {
    final paidCtrl = TextEditingController(text: booking.paidAmount.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل المبلغ المدفوع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سعر الرحلة: ${trip.price.toStringAsFixed(0)} جنيه'),
            const SizedBox(height: 12),
            TextField(
              controller: paidCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ الجديد'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final paid = double.tryParse(paidCtrl.text.trim()) ?? 0;
    await tripProv.updatePaidAmount(booking.id, paid);
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId,
      String studentName, TripProvider tripProv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: Text('هتشيل $studentName من الرحلة دي نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('شيل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await tripProv.deleteBooking(bookingId);
    }
  }
}
