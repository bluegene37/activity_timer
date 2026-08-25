import 'package:flutter/material.dart';

import '../models/brew_recipe.dart';

class BrewEditScreen extends StatefulWidget {
  const BrewEditScreen({required this.recipe, required this.isNew, super.key});

  final BrewRecipe recipe;
  final bool isNew;

  @override
  State<BrewEditScreen> createState() => _BrewEditScreenState();
}

class _BrewEditScreenState extends State<BrewEditScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
