import 'dart:convert';

class Note {
  final int? id;
  final String text;
  final List<String> imageBase64List;
  final DateTime dateTime;
  final double? latitude;
  final double? longitude;

  Note({
    this.id,
    required this.text,
    required this.imageBase64List,
    required this.dateTime,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'imageBase64List': jsonEncode(imageBase64List),
      'dateTime': dateTime.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    List<String> images = [];
    if (map['imageBase64List'] != null) {
      final decoded = jsonDecode(map['imageBase64List']);
      images = List<String>.from(decoded);
    }

    return Note(
      id: map['id'] as int?, // Will be overridden by DBHelper
      text: map['text'] ?? '',
      imageBase64List: images,
      dateTime: DateTime.parse(map['dateTime']),
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
    );
  }

  /// Returns a copy of the note with updated fields (used for setting ID after fetch)
  Note copyWith({int? id}) {
    return Note(
      id: id ?? this.id,
      text: text,
      imageBase64List: imageBase64List,
      dateTime: dateTime,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
