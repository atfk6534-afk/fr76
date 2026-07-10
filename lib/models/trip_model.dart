import 'package:hive/hive.dart';

/// نموذج رحلة واحدة
class TripModel {
  final String id;
  String name;
  String description;
  String dateKey;       // yyyy-MM-dd
  double price;         // السعر الكامل بالجنيه
  String createdBy;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isDeleted;

  TripModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.dateKey,
    required this.price,
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  TripModel copyWith({
    String? name,
    String? description,
    String? dateKey,
    double? price,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return TripModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      dateKey: dateKey ?? this.dateKey,
      price: price ?? this.price,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'dateKey': dateKey,
        'price': price,
        'createdBy': createdBy,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'isDeleted': isDeleted,
      };

  factory TripModel.fromMap(Map<String, dynamic> m) => TripModel(
        id: m['id'] as String,
        name: m['name'] as String,
        description: (m['description'] as String?) ?? '',
        dateKey: m['dateKey'] as String,
        price: ((m['price'] as num?) ?? 0).toDouble(),
        createdBy: (m['createdBy'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
        isDeleted: (m['isDeleted'] as bool?) ?? false,
      );
}

class TripModelAdapter extends TypeAdapter<TripModel> {
  @override
  final int typeId = 4;

  @override
  TripModel read(BinaryReader reader) {
    final m = reader.readMap();
    return TripModel(
      id: m['id'] as String,
      name: m['name'] as String,
      description: (m['description'] as String?) ?? '',
      dateKey: m['dateKey'] as String,
      price: ((m['price'] as num?) ?? 0).toDouble(),
      createdBy: (m['createdBy'] as String?) ?? '',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
      isDeleted: (m['isDeleted'] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, TripModel obj) {
    writer.writeMap({
      'id': obj.id,
      'name': obj.name,
      'description': obj.description,
      'dateKey': obj.dateKey,
      'price': obj.price,
      'createdBy': obj.createdBy,
      'createdAt': obj.createdAt.millisecondsSinceEpoch,
      'updatedAt': obj.updatedAt.millisecondsSinceEpoch,
      'isDeleted': obj.isDeleted,
    });
  }
}

/// نموذج حجز شاب في رحلة
class TripBooking {
  final String id;         // tripId_studentId
  final String tripId;
  final String studentId;
  double paidAmount;       // المبلغ المدفوع فعلاً
  String addedBy;          // الخادم الذي أضاف الحجز
  final DateTime createdAt;
  DateTime updatedAt;
  bool isDeleted;

  TripBooking({
    required this.id,
    required this.tripId,
    required this.studentId,
    required this.paidAmount,
    this.addedBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  static String buildId(String tripId, String studentId) =>
      '${tripId}_$studentId';

  TripBooking copyWith({
    double? paidAmount,
    String? addedBy,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return TripBooking(
      id: id,
      tripId: tripId,
      studentId: studentId,
      paidAmount: paidAmount ?? this.paidAmount,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tripId': tripId,
        'studentId': studentId,
        'paidAmount': paidAmount,
        'addedBy': addedBy,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'isDeleted': isDeleted,
      };

  factory TripBooking.fromMap(Map<String, dynamic> m) => TripBooking(
        id: m['id'] as String,
        tripId: m['tripId'] as String,
        studentId: m['studentId'] as String,
        paidAmount: ((m['paidAmount'] as num?) ?? 0).toDouble(),
        addedBy: (m['addedBy'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
        isDeleted: (m['isDeleted'] as bool?) ?? false,
      );
}

class TripBookingAdapter extends TypeAdapter<TripBooking> {
  @override
  final int typeId = 5;

  @override
  TripBooking read(BinaryReader reader) {
    final m = reader.readMap();
    return TripBooking(
      id: m['id'] as String,
      tripId: m['tripId'] as String,
      studentId: m['studentId'] as String,
      paidAmount: ((m['paidAmount'] as num?) ?? 0).toDouble(),
      addedBy: (m['addedBy'] as String?) ?? '',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
      isDeleted: (m['isDeleted'] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, TripBooking obj) {
    writer.writeMap({
      'id': obj.id,
      'tripId': obj.tripId,
      'studentId': obj.studentId,
      'paidAmount': obj.paidAmount,
      'addedBy': obj.addedBy,
      'createdAt': obj.createdAt.millisecondsSinceEpoch,
      'updatedAt': obj.updatedAt.millisecondsSinceEpoch,
      'isDeleted': obj.isDeleted,
    });
  }
}
