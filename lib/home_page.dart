import 'package:flutter/material.dart';
import 'features/chat/character_selection_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key}); // ✅ Added 'const' here

  @override
  Widget build(BuildContext context) {
    return CharacterSelectionPage();
  }
}