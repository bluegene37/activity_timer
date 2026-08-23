import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ColorSelector extends StatefulWidget {
  final Color selectedColor;
  final void Function(Color) onColorSelected;

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

  // Apple System & Fitness Color Palette
  final List<Color> _colorOptions = const [
    AppTheme.iosOrange,
    AppTheme.iosBlue,
    AppTheme.iosGreen,
    AppTheme.iosMint,
    AppTheme.iosTeal,
    AppTheme.iosIndigo,
    AppTheme.iosPurple,
    AppTheme.iosPink,
    AppTheme.iosRed,
    AppTheme.iosYellow,
    Color(0xFF3333A3), // Classic deep indigo
    Color(0xFF607D8B), // Slate gray
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedColor();
    });
  }

  void _scrollToSelectedColor() {
    final index = _colorOptions.indexWhere(
      (color) => color.toARGB32() == _selectedColor.toARGB32(),
    );
    if (index != -1 && _scrollController.hasClients) {
      final offset = index * 52.0;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
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
        SizedBox(
          height: 52,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _colorOptions.length,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemBuilder: (context, index) {
              final color = _colorOptions[index];
              final isSelected = color.toARGB32() == _selectedColor.toARGB32();
              final iconColor = _isLightColor(color) ? Colors.black : Colors.white;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedColor = color;
                  });
                  widget.onColorSelected(color);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: isSelected ? 0.45 : 0.2),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: iconColor,
                          size: 20,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Swipe horizontally to choose an accent color',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
