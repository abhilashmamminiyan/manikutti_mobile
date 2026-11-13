import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  static Future<Color?> show(BuildContext context, {Color? currentColor}) {
    return showDialog<Color>(
      context: context,
      builder: (ctx) =>
          ColorPickerDialog(initialColor: currentColor ?? AppTheme.primary),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;
  late TextEditingController _hexController;

  static const List<Map<String, dynamic>> _presets = [
    {'name': 'Heritage Teal', 'color': Color(0xFF006972)},
    {'name': 'Ocean Blue', 'color': Color(0xFF1565C0)},
    {'name': 'Sky Cerulean', 'color': Color(0xFF0288D1)},
    {'name': 'Royal Indigo', 'color': Color(0xFF3949AB)},
    {'name': 'Deep Purple', 'color': Color(0xFF6A1B9A)},
    {'name': 'Violet Neon', 'color': Color(0xFF7C4DFF)},
    {'name': 'Magenta Rose', 'color': Color(0xFFC2185B)},
    {'name': 'Crimson Ruby', 'color': Color(0xFFC62828)},
    {'name': 'Tangerine', 'color': Color(0xFFE65100)},
    {'name': 'Amber Gold', 'color': Color(0xFFF57F17)},
    {'name': 'Emerald Green', 'color': Color(0xFF2E7D32)},
    {'name': 'Mint Teal', 'color': Color(0xFF00897B)},
    {'name': 'Forest Pine', 'color': Color(0xFF1B5E20)},
    {'name': 'Steel Charcoal', 'color': Color(0xFF37474F)},
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    if (cleanHex.length == 8) {
      final val = int.tryParse(cleanHex, radix: 16);
      if (val != null) {
        return Color(val);
      }
    }
    return null;
  }

  void _onColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
      _hexController.text = _colorToHex(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final red = (_selectedColor.r * 255.0).round().clamp(0, 255);
    final green = (_selectedColor.g * 255.0).round().clamp(0, 255);
    final blue = (_selectedColor.b * 255.0).round().clamp(0, 255);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.palette_rounded, color: _selectedColor, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Choose App Theme Color'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Preview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Theme Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _colorToHex(_selectedColor),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Curated Swatches
            Text(
              'Preset Palettes',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) {
                final color = p['color'] as Color;
                final isSelected =
                    _selectedColor.toARGB32() == color.toARGB32();

                return GestureDetector(
                  onTap: () => _onColorChanged(color),
                  child: Tooltip(
                    message: p['name'] as String,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Hex Code Input
            Text(
              'Custom Hex Code',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    decoration: InputDecoration(
                      hintText: '#006972',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.tag, size: 18),
                    ),
                    onChanged: (val) {
                      final parsed = _hexToColor(val);
                      if (parsed != null) {
                        setState(() => _selectedColor = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _onColorChanged(AppTheme.defaultPrimary),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // RGB Sliders for Granular Tuning
            Text(
              'RGB Fine Tuning',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),

            // Red Slider
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  child: Text(
                    'R',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: red.toDouble(),
                    min: 0,
                    max: 255,
                    activeColor: Colors.red,
                    onChanged: (v) {
                      _onColorChanged(
                        Color.fromARGB(255, v.round(), green, blue),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$red', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Green Slider
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: green.toDouble(),
                    min: 0,
                    max: 255,
                    activeColor: Colors.green,
                    onChanged: (v) {
                      _onColorChanged(
                        Color.fromARGB(255, red, v.round(), blue),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$green', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Blue Slider
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  child: Text(
                    'B',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: blue.toDouble(),
                    min: 0,
                    max: 255,
                    activeColor: Colors.blue,
                    onChanged: (v) {
                      _onColorChanged(
                        Color.fromARGB(255, red, green, v.round()),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$blue', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Apply Color'),
        ),
      ],
    );
  }
}
