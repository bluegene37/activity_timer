import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorSelector extends StatefulWidget {
  final Color selectedColor;
  final Function(Color) onColorSelected;

  const ColorSelector({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<ColorSelector> createState() => _ColorSelectorState();
}

class _ColorSelectorState extends State<ColorSelector> {
  late Color _selectedColor;
  final ScrollController _scrollController = ScrollController();

  // Predefined color options - swapped Blue (index 0) with Yellow (index 5)
  final List<Color> _colorOptions = [
    const Color(0xFFFFEB3B), // Yellow
    const Color(0xFF000000), // Black
    const Color(0xFF1A237E), // Indigo 900 (Navy)
    const Color(0xFF311B92), // Deep Purple 900
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFE91E63), // Pink
    const Color(0xFFF44336), // Red
    const Color(0xFFFF9800), // Orange
    const Color(0xFF4A6FFF), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFF009688), // Teal
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFF607D8B), // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;

    // Scroll to the selected color
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedColor();
    });
  }

  void _scrollToSelectedColor() {
    final index = _colorOptions.indexWhere(
      (color) => color.toARGB32() == _selectedColor.toARGB32(),
    );
    if (index != -1) {
      final itemWidth = 60.0; // Width of each color item
      final offset = index * itemWidth;

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // Helper method to determine if a color is light or dark
  bool _isLightColor(Color color) {
    // Calculate luminance to determine if color is light or dark
    final luminance = color.computeLuminance();
    return luminance > 0.5;
  }

  // Helper method to get appropriate icon color based on background
  Color _getIconColor(Color backgroundColor) {
    return _isLightColor(backgroundColor) ? Colors.black87 : Colors.white;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _colorOptions.length,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final color = _colorOptions[index];
              final isSelected = color == _selectedColor;
              final iconColor = _getIconColor(color);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                  widget.onColorSelected(color);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                            : null,
                  ),
                  child:
                      isSelected
                          ? Icon(
                            Icons.check,
                            color:
                                iconColor, // Dynamic color based on background
                            size: 24,
                          )
                          : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          'Swipe horizontally to see more colors',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
