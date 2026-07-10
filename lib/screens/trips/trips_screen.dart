import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../core/constants/app_colors.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final trips = context.watch<TripProvider>().allTrips;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرحلات'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'رحلة جديدة',
              onPressed: () => _showAddTripDialog(context),
            ),
        ],
      ),
      body: trips.isEmpty
          ? const Center(
              child: Text('مفيش رحلات مضافة لحد دلوقتي',
                  style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: trips.length,
              itemBuilder: (ctx, i) => _TripCard(trip: trips[i]),
            ),
    );
  }

  Future<void> _showAddTripDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    DateTime? pickedDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة رحلة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'اسم الرحلة *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'تفاصيل/وصف الرحلة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'السعر (جنيه) *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 20,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pickedDate == null
                            ? 'اختر تاريخ الرحلة *'
                            : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: pickedDate == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 30)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (d != null) setSt(() => pickedDate = d);
                      },
                      child: const Text('اختر'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إضافة')),
          ],
        ),
      ),
    );

    if (result != true) return;
    if (nameCtrl.text.trim().isEmpty ||
        priceCtrl.text.trim().isEmpty ||
        pickedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الاسم والسعر والتاريخ مطلوبين')));
      return;
    }

    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final dateKey =
        '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}';
    final user = context.read<AuthProvider>().currentUser;

    await context.read<TripProvider>().addTrip(
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
          dateKey: dateKey,
          price: price,
          createdBy: user?.name ?? '',
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة رحلة "${nameCtrl.text.trim()}"')));
    }
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final stats = context.read<TripProvider>().tripStats(trip.id);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TripDetailScreen(tripId: trip.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(trip.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.absent),
                      tooltip: 'حذف الرحلة',
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              ),
              if (trip.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(trip.description,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip(Icons.calendar_today_outlined, trip.dateKey),
                  const SizedBox(width: 8),
                  _chip(Icons.attach_money_rounded,
                      '${trip.price.toStringAsFixed(0)} جنيه'),
                  const SizedBox(width: 8),
                  _chip(Icons.people_outline,
                      '${stats.bookings} حاجز'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: stats.totalExpected > 0
                    ? (stats.totalCollected / stats.totalExpected)
                        .clamp(0.0, 1.0)
                    : 0,
                backgroundColor: AppColors.divider,
                color: AppColors.present,
              ),
              const SizedBox(height: 2),
              Text(
                'تم تحصيل ${stats.totalCollected.toStringAsFixed(0)} من ${stats.totalExpected.toStringAsFixed(0)} جنيه',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(label,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ حذف الرحلة'),
        content: Text(
          'هيتم حذف رحلة "${trip.name}" وكل الحجوزات المرتبطة بيها نهائياً.\nمش هترجع. متأكد؟',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('احذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<TripProvider>().deleteTrip(trip.id);
    }
  }
}
