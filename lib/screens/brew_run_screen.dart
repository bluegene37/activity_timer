import 'package:flutter/material.dart';

import '../models/brew_recipe.dart';

class BrewRunScreen extends StatefulWidget {
  const BrewRunScreen({required this.recipe, super.key});

  final BrewRecipe recipe;

  @override
  State<BrewRunScreen> createState() => _BrewRunScreenState();
}

class _BrewRunScreenState extends State<BrewRunScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
