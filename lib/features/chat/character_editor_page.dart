import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ai_companion/models/character.dart';

class CharacterEditorPage extends StatefulWidget {
  final Character character;

  const CharacterEditorPage({
    super.key,
    required this.character,
  });

  @override
  State<CharacterEditorPage> createState() =>
      _CharacterEditorPageState();
}

class _CharacterEditorPageState
    extends State<CharacterEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _greetingController;
  late final TextEditingController _traitsController;
  late final TextEditingController _behaviorsController;
  late final TextEditingController _creatorPromptController;

  late CharacterPersonality _personality;

  String? _avatarPath;

  bool _saving = false;

  final ImagePicker _imagePicker =
      ImagePicker();

  @override
  void initState() {
    super.initState();

    final character = widget.character;

    _nameController =
        TextEditingController(
      text: character.name,
    );

    _descriptionController =
        TextEditingController(
      text: character.description,
    );

    _greetingController =
        TextEditingController(
      text: character.greeting,
    );

    _traitsController =
        TextEditingController(
      text: character.traits.join(', '),
    );

    _behaviorsController =
        TextEditingController(
      text: character.behaviors.join(', '),
    );

    _creatorPromptController =
        TextEditingController(
      text: character.creatorPrompt,
    );

    _personality =
        character.personality;

    _avatarPath =
        character.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _greetingController.dispose();
    _traitsController.dispose();
    _behaviorsController.dispose();
    _creatorPromptController.dispose();

    super.dispose();
  }

  // ============================================================
  // PICK PROFILE PHOTO
  // ============================================================

  Future<void> _pickAvatar() async {
    try {
      final picked =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (picked == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _avatarPath = picked.path;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal memilih foto: $e',
      );
    }
  }

  // ============================================================
  // REMOVE PHOTO
  // ============================================================

  void _removeAvatar() {
    setState(() {
      _avatarPath = null;
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  void _save() {
    if (_saving) {
      return;
    }

    final name =
        _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Nama character tidak boleh kosong.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final updatedCharacter =
        widget.character.copyWith(
      name: name,

      avatarPath:
          _avatarPath,

      personality:
          _personality,

      description:
          _descriptionController.text
              .trim(),

      greeting:
          _greetingController.text
              .trim(),

      traits:
          _parseList(
        _traitsController.text,
      ),

      behaviors:
          _parseList(
        _behaviorsController.text,
      ),

      creatorPrompt:
          _creatorPromptController.text
              .trim(),
    );

    Navigator.pop(
      context,
      updatedCharacter,
    );
  }

  // ============================================================
  // PARSE LIST
  // ============================================================

  List<String> _parseList(
    String value,
  ) {
    return value
        .split(',')
        .map(
          (item) => item.trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // AVATAR WIDGET
  // ============================================================

  Widget _buildAvatar() {
    final path = _avatarPath;

    Widget avatar;

    if (path != null &&
        path.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius:
            BorderRadius.circular(34),
        child: Image.file(
          File(path),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder:
              (
            context,
            error,
            stackTrace,
          ) {
            return _defaultAvatar();
          },
        ),
      );
    } else {
      avatar = _defaultAvatar();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,

        Positioned(
          right: -4,
          bottom: -4,
          child: Material(
            color: Theme.of(context)
                .colorScheme
                .primary,
            shape:
                const CircleBorder(),
            child: InkWell(
              customBorder:
                  const CircleBorder(),
              onTap: _pickAvatar,
              child: const Padding(
                padding:
                    EdgeInsets.all(10),
                child: Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: widget.character.color
            .withValues(
          alpha: 0.15,
        ),
        borderRadius:
            BorderRadius.circular(34),
      ),
      child: Icon(
        widget.character.icon,
        size: 56,
        color:
            widget.character.color,
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    Widget? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        border:
            const OutlineInputBorder(),
        alignLabelWithHint:
            maxLines > 1,
      ),
    );
  }

  // ============================================================
  // PERSONALITY NAME
  // ============================================================

  String _personalityName(
    CharacterPersonality personality,
  ) {
    switch (personality) {
      case CharacterPersonality.friendly:
        return 'Friendly';

      case CharacterPersonality.funny:
        return 'Funny';

      case CharacterPersonality.serious:
        return 'Serious';

      case CharacterPersonality.ayvan:
        return 'Ayvan';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Character',
          style:
              GoogleFonts.poppins(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 8,
            ),
            child: TextButton(
              onPressed:
                  _saving ? null : _save,
              child: Text(
                'SAVE',
                style:
                    GoogleFonts.poppins(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            40,
          ),
          children: [
            // ----------------------------------------------------
            // PROFILE PHOTO
            // ----------------------------------------------------

            Center(
              child: Column(
                children: [
                  _buildAvatar(),

                  const SizedBox(
                    height: 14,
                  ),

                  TextButton.icon(
                    onPressed:
                        _pickAvatar,
                    icon: const Icon(
                      Icons.photo_library,
                    ),
                    label: Text(
                      'Change profile photo',
                      style:
                          GoogleFonts.poppins(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  if (_avatarPath !=
                      null)
                    TextButton(
                      onPressed:
                          _removeAvatar,
                      child: Text(
                        'Remove photo',
                        style:
                            GoogleFonts
                                .poppins(
                          color:
                              colorScheme
                                  .error,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            // ----------------------------------------------------
            // BASIC INFORMATION
            // ----------------------------------------------------

            Text(
              'Basic Information',
              style:
                  GoogleFonts.poppins(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _field(
              label: 'Name',
              hint:
                  'Character name',
              controller:
                  _nameController,
              prefixIcon:
                  const Icon(
                Icons.person_outline,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            _field(
              label: 'Description',
              hint:
                  'Short description',
              controller:
                  _descriptionController,
              maxLines: 3,
              prefixIcon:
                  const Icon(
                Icons.description_outlined,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            DropdownButtonFormField<
                CharacterPersonality>(
              initialValue:
                  _personality,
              decoration:
                  const InputDecoration(
                labelText:
                    'Personality',
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.psychology_outlined,
                ),
              ),
              items:
                  CharacterPersonality
                      .values
                      .map(
                (personality) {
                  return DropdownMenuItem(
                    value:
                        personality,
                    child: Text(
                      _personalityName(
                        personality,
                      ),
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  (value) {
                if (value ==
                    null) {
                  return;
                }

                setState(() {
                  _personality =
                      value;
                });
              },
            ),

            const SizedBox(
              height: 28,
            ),

            // ----------------------------------------------------
            // CONVERSATION
            // ----------------------------------------------------

            Text(
              'Conversation',
              style:
                  GoogleFonts.poppins(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _field(
              label: 'Greeting',
              hint:
                  'First message from the character',
              controller:
                  _greetingController,
              maxLines: 3,
              prefixIcon:
                  const Icon(
                Icons.waving_hand_outlined,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            _field(
              label: 'Traits',
              hint:
                  'friendly, curious, playful',
              controller:
                  _traitsController,
              maxLines: 2,
              prefixIcon:
                  const Icon(
                Icons.favorite_border,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Separate each trait with a comma.',
              style:
                  GoogleFonts.poppins(
                fontSize: 11,
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            _field(
              label: 'Behavior',
              hint:
                  'casual, jokes often, speaks naturally',
              controller:
                  _behaviorsController,
              maxLines: 3,
              prefixIcon:
                  const Icon(
                Icons.theater_comedy_outlined,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Separate each behavior with a comma.',
              style:
                  GoogleFonts.poppins(
                fontSize: 11,
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            // ----------------------------------------------------
            // CREATOR PROMPT
            // ----------------------------------------------------

            Text(
              'Creator Prompt',
              style:
                  GoogleFonts.poppins(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'This prompt defines how the AI should behave. '
              'It will be used later by the AI service.',
              style:
                  GoogleFonts.poppins(
                fontSize: 12,
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _field(
              label:
                  'Creator Prompt',
              hint:
                  'Describe how this AI should act...',
              controller:
                  _creatorPromptController,
              maxLines: 8,
              prefixIcon:
                  const Icon(
                Icons.code_outlined,
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            // ----------------------------------------------------
            // SAVE BUTTON
            // ----------------------------------------------------

            SizedBox(
              height: 54,
              child:
                  FilledButton.icon(
                onPressed:
                    _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.save_outlined,
                      ),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : 'Save Character',
                  style:
                      GoogleFonts.poppins(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Center(
              child: Text(
                'Character ID: ${widget.character.id}',
                style:
                    GoogleFonts.poppins(
                  fontSize: 10,
                  color: colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}