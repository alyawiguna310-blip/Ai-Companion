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
  late final TextEditingController _creatorPromptController;

  final ImagePicker _imagePicker = ImagePicker();

  late CharacterPersonality _personality;

  late List<String> _traits;
  late List<String> _behaviors;

  @override
  void initState() {
    super.initState();

    final character = widget.character;

    _nameController = TextEditingController(
      text: character.name,
    );

    _descriptionController = TextEditingController(
      text: character.description,
    );

    _greetingController = TextEditingController(
      text: character.greeting,
    );

    _creatorPromptController = TextEditingController(
      text: character.creatorPrompt,
    );

    _personality = character.personality;

    _traits = List<String>.from(
      character.traits,
    );

    _behaviors = List<String>.from(
      character.behaviors,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _greetingController.dispose();
    _creatorPromptController.dispose();

    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) {
        return;
      }

      setState(() {
        widget.character.avatarPath = image.path;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to select profile photo.',
      );
    }
  }

  void _saveCharacter() {
    final character = widget.character;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Character name cannot be empty.',
      );
      return;
    }

    character.name = name;

    character.description =
        _descriptionController.text.trim();

    character.greeting =
        _greetingController.text.trim().isEmpty
            ? 'Halo! 👋'
            : _greetingController.text.trim();

    character.creatorPrompt =
        _creatorPromptController.text.trim();

    character.personality = _personality;

    character.traits =
        List<String>.from(_traits);

    character.behaviors =
        List<String>.from(_behaviors);

    Navigator.pop(context, true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addTrait() async {
    final value = await _showTextInputDialog(
      title: 'Add Trait',
      hint: 'Example: Playful',
    );

    if (value == null ||
        value.trim().isEmpty) {
      return;
    }

    final trait = value.trim();

    if (_traits.contains(trait)) {
      _showMessage(
        'This trait already exists.',
      );
      return;
    }

    setState(() {
      _traits.add(trait);
    });
  }

  Future<void> _addBehavior() async {
    final value = await _showTextInputDialog(
      title: 'Add Behavior',
      hint: 'Example: Speak casually',
    );

    if (value == null ||
        value.trim().isEmpty) {
      return;
    }

    final behavior = value.trim();

    if (_behaviors.contains(behavior)) {
      _showMessage(
        'This behavior already exists.',
      );
      return;
    }

    setState(() {
      _behaviors.add(behavior);
    });
  }

  Future<String?> _showTextInputDialog({
    required String title,
    required String hint,
  }) async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization:
                TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              border:
                  const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.pop(
                context,
                value,
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text,
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

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
        return 'Ayvan Mode';
    }
  }

  IconData _personalityIcon(
    CharacterPersonality personality,
  ) {
    switch (personality) {
      case CharacterPersonality.friendly:
        return Icons.favorite_outline;

      case CharacterPersonality.funny:
        return Icons.sentiment_very_satisfied;

      case CharacterPersonality.serious:
        return Icons.business_center_outlined;

      case CharacterPersonality.ayvan:
        return Icons.auto_awesome;
    }
  }

  Widget _buildProfileImage(
    Character character,
  ) {
    final path = character.avatarPath;

    if (path == null || path.isEmpty) {
      return Icon(
        character.icon,
        size: 52,
        color: character.color,
      );
    }

    return ClipOval(
      child: Image.file(
        File(path),
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return Icon(
            character.icon,
            size: 52,
            color: character.color,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    final character = widget.character;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customize ${character.name}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveCharacter,
            child: const Text('SAVE'),
          ),
        ],
      ),

      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          40,
        ),

        children: [
          // =========================
          // PROFILE
          // =========================

          Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color:
                      character.color.withValues(
                    alpha: 0.14,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        character.color.withValues(
                      alpha: 0.45,
                    ),
                    width: 2,
                  ),
                ),
                child:
                    _buildProfileImage(
                  character,
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed:
                    _pickProfilePhoto,
                icon: const Icon(
                  Icons.photo_camera_outlined,
                ),
                label: const Text(
                  'Change Profile Photo',
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Personalize your companion',
                style:
                    GoogleFonts.poppins(
                  fontSize: 11,
                  color: colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // =========================
          // BASIC INFORMATION
          // =========================

          _buildSectionTitle(
            'Basic Information',
            Icons.person_outline,
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller:
                _nameController,
            label: 'Name',
            hint: 'Character name',
            icon:
                Icons.badge_outlined,
          ),

          const SizedBox(height: 14),

          _buildTextField(
            controller:
                _descriptionController,
            label: 'Description',
            hint:
                'Short character description',
            icon: Icons
                .description_outlined,
            maxLines: 3,
          ),

          const SizedBox(height: 28),

          // =========================
          // PERSONALITY
          // =========================

          _buildSectionTitle(
            'Personality',
            Icons.psychology_outlined,
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                CharacterPersonality
                    .values
                    .map(
              (personality) =>
                  ChoiceChip(
                avatar: Icon(
                  _personalityIcon(
                    personality,
                  ),
                  size: 18,
                ),
                label: Text(
                  _personalityName(
                    personality,
                  ),
                ),
                selected:
                    _personality ==
                        personality,
                onSelected:
                    (selected) {
                  if (!selected) {
                    return;
                  }

                  setState(() {
                    _personality =
                        personality;
                  });
                },
              ),
            )
                    .toList(),
          ),

          const SizedBox(height: 28),

          // =========================
          // TRAITS
          // =========================

          _buildSectionTitle(
            'Traits',
            Icons.auto_awesome_outlined,
          ),

          const SizedBox(height: 8),

          Text(
            'Define the personality traits of your companion.',
            style:
                GoogleFonts.poppins(
              fontSize: 12,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 12),

          if (_traits.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _traits.map(
                (trait) {
                  return InputChip(
                    label:
                        Text(trait),
                    deleteIcon:
                        const Icon(
                      Icons.close,
                      size: 16,
                    ),
                    onDeleted:
                        () {
                      setState(() {
                        _traits
                            .remove(
                          trait,
                        );
                      });
                    },
                  );
                },
              ).toList(),
            ),

          if (_traits.isNotEmpty)
            const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _addTrait,
            icon:
                const Icon(Icons.add),
            label:
                const Text(
              'Add Trait',
            ),
          ),

          const SizedBox(height: 28),

          // =========================
          // BEHAVIOR
          // =========================

          _buildSectionTitle(
            'Behavior',
            Icons.theater_comedy_outlined,
          ),

          const SizedBox(height: 8),

          Text(
            'Control how the AI behaves during conversations.',
            style:
                GoogleFonts.poppins(
              fontSize: 12,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 12),

          if (_behaviors.isNotEmpty)
            Column(
              children:
                  _behaviors
                      .asMap()
                      .entries
                      .map(
                (entry) {
                  return Card(
                    margin:
                        const EdgeInsets
                            .only(
                      bottom: 8,
                    ),
                    child: ListTile(
                      leading:
                          CircleAvatar(
                        radius: 17,
                        child: Text(
                          '${entry.key + 1}',
                        ),
                      ),
                      title: Text(
                        entry.value,
                        style:
                            GoogleFonts
                                .poppins(
                          fontSize: 13,
                        ),
                      ),
                      trailing:
                          IconButton(
                        tooltip:
                            'Remove',
                        onPressed:
                            () {
                          setState(() {
                            _behaviors
                                .removeAt(
                              entry.key,
                            );
                          });
                        },
                        icon:
                            const Icon(
                          Icons
                              .delete_outline,
                        ),
                      ),
                    ),
                  );
                },
              ).toList(),
            ),

          OutlinedButton.icon(
            onPressed:
                _addBehavior,
            icon:
                const Icon(Icons.add),
            label:
                const Text(
              'Add Behavior',
            ),
          ),

          const SizedBox(height: 28),

          // =========================
          // GREETING
          // =========================

          _buildSectionTitle(
            'Greeting',
            Icons.waving_hand_outlined,
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller:
                _greetingController,
            label:
                'Opening Message',
            hint:
                'What should the companion say first?',
            icon: Icons
                .chat_bubble_outline,
            maxLines: 3,
          ),

          const SizedBox(height: 28),

          // =========================
          // CREATOR PROMPT
          // =========================

          _buildSectionTitle(
            'Creator Prompt',
            Icons.code_outlined,
          ),

          const SizedBox(height: 8),

          Text(
            'This prompt defines the core instructions and behavior of the AI.',
            style:
                GoogleFonts.poppins(
              fontSize: 12,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 12),

          _buildTextField(
            controller:
                _creatorPromptController,
            label:
                'Creator Prompt',
            hint:
                'Write instructions that define this character...',
            icon: Icons
                .smart_toy_outlined,
            maxLines: 10,
          ),

          const SizedBox(height: 36),

          // =========================
          // SAVE
          // =========================

          FilledButton.icon(
            onPressed:
                _saveCharacter,
            icon: const Icon(
              Icons.save_outlined,
            ),
            label: const Text(
              'Save Character',
            ),
            style:
                FilledButton.styleFrom(
              minimumSize:
                  const Size(
                double.infinity,
                54,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 21,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style:
              GoogleFonts.poppins(
            fontSize: 18,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization:
          TextCapitalization
              .sentences,
      decoration:
          InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            Icon(icon),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          borderSide:
              BorderSide(
            color: Theme.of(
              context,
            )
                .colorScheme
                .primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}