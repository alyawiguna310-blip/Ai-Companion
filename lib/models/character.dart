import 'package:flutter/material.dart';

enum CharacterPersonality {
  friendly,
  funny,
  serious,
  ayvan,
}

/// Compatibility alias untuk kode lama project.
typedef AIPersonality = CharacterPersonality;

class Character {
  final String id;

  /// Nama karakter.
  String name;

  /// Path foto profil karakter.
  ///
  /// Bisa berupa asset path atau file path dari galeri.
  String? avatarPath;

  /// Icon fallback jika karakter belum mempunyai foto.
  IconData icon;

  /// Warna fallback untuk avatar/icon.
  Color color;

  /// Personality utama karakter.
  CharacterPersonality personality;

  /// Deskripsi singkat karakter.
  String description;

  /// Pesan pembuka ketika chat dimulai.
  String greeting;

  /// Sifat-sifat karakter.
  List<String> traits;

  /// Behavior atau gaya perilaku karakter.
  List<String> behaviors;

  /// Prompt yang dibuat oleh pembuat karakter.
  String creatorPrompt;

  Character({
    required this.id,
    required this.name,
    this.avatarPath,
    required this.icon,
    required this.color,
    required this.personality,
    required this.description,
    this.greeting = 'Halo! 👋',
    this.traits = const [],
    this.behaviors = const [],
    this.creatorPrompt = '',
  });

  /// Mengubah Character menjadi Map untuk disimpan.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarPath': avatarPath,

      // Icon disimpan untuk kompatibilitas data.
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,

      'colorValue': color.toARGB32(),

      'personality': personality.name,

      'description': description,

      'greeting': greeting,

      'traits': List<String>.from(traits),

      'behaviors': List<String>.from(behaviors),

      'creatorPrompt': creatorPrompt,
    };
  }

  /// Membuat Character dari data yang tersimpan.
  factory Character.fromJson(
    Map<String, dynamic> json,
  ) {
    final personalityName =
        json['personality']?.toString();

    final personality =
        CharacterPersonality.values.firstWhere(
      (value) =>
          value.name == personalityName,
      orElse: () =>
          CharacterPersonality.friendly,
    );

    final colorValue =
        (json['colorValue'] as num?)?.toInt();

    final color = Color(
      colorValue ??
          Colors.purple.toARGB32(),
    );

    final rawTraits = json['traits'];

    final rawBehaviors =
        json['behaviors'];

    return Character(
      id: json['id']?.toString() ?? '',
      
      name: json['name']?.toString() ??
          'AI Companion',

      avatarPath:
          json['avatarPath']?.toString(),

      // Untuk menghindari masalah const IconData
      // ketika membaca data dari JSON, gunakan
      // icon fallback standar.
      icon: Icons.smart_toy,

      color: color,

      personality: personality,

      description:
          json['description']?.toString() ??
              '',

      greeting:
          json['greeting']?.toString() ??
              'Halo! 👋',

      traits:
          rawTraits is List
              ? rawTraits
                  .map(
                    (item) =>
                        item.toString(),
                  )
                  .toList()
              : <String>[],

      behaviors:
          rawBehaviors is List
              ? rawBehaviors
                  .map(
                    (item) =>
                        item.toString(),
                  )
                  .toList()
              : <String>[],

      creatorPrompt:
          json['creatorPrompt']
                  ?.toString() ??
              '',
    );
  }

  /// Membuat salinan Character dengan
  /// perubahan property tertentu.
  Character copyWith({
    String? name,
    String? avatarPath,
    IconData? icon,
    Color? color,
    CharacterPersonality? personality,
    String? description,
    String? greeting,
    List<String>? traits,
    List<String>? behaviors,
    String? creatorPrompt,
  }) {
    return Character(
      id: id,

      name: name ?? this.name,

      avatarPath:
          avatarPath ?? this.avatarPath,

      icon: icon ?? this.icon,

      color: color ?? this.color,

      personality:
          personality ?? this.personality,

      description:
          description ?? this.description,

      greeting:
          greeting ?? this.greeting,

      traits:
          traits ??
              List<String>.from(
                this.traits,
              ),

      behaviors:
          behaviors ??
              List<String>.from(
                this.behaviors,
              ),

      creatorPrompt:
          creatorPrompt ??
              this.creatorPrompt,
    );
  }
}