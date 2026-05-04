import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill_delta;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'math_symbol_toolbar.dart';
import '../../core/utils/math_utils.dart';

class MathEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'math';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final latex = embedContext.node.value.data as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      key: ValueKey('math_$latex'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.getBorderColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Math.tex(
            latex,
            textStyle: TextStyle(
              fontSize: 18,
              color: textColor,
            ),
            onErrorFallback: (err) => Text(
              latex,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RichTextEditor extends StatefulWidget {
  final String? initialHtml;
  final Function(String) onContentChanged;
  final String placeholder;
  final double height;
  final bool isCompact;
  final Color? textColor;

  const RichTextEditor({
    super.key,
    this.initialHtml,
    required this.onContentChanged,
    this.placeholder = 'اكتب هنا...',
    this.height = 200,
    this.isCompact = false,
    this.textColor,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isFocused = false;

  quill.Style get _selectionStyle => _controller.getSelectionStyle();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHtml != oldWidget.initialHtml) {
      _controller.removeListener(_onContentChanged);
      _controller.dispose();
      _initializeController();
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _initializeController() {
    try {
      if (widget.initialHtml != null && widget.initialHtml!.isNotEmpty) {
        // Normalize HTML first (handles Word equations and fix style attributes)
        String html = MathUtils.normalizeMathContent(widget.initialHtml!);
        
        // Normalize color/background formatting: lowercase hex, space after colon
        html = html.replaceAllMapped(RegExp(r'style="([^"]*)"'), (match) {
          String style = match.group(1)!;
          style = style.toLowerCase()
              .replaceAll(RegExp(r':\s*'), ': ')
              .replaceAll(RegExp(r';\s*'), '; ');
          return 'style="$style"';
        });

        // CRITICAL: Wrap colored text in block elements (h1-h6, p) with <span> 
        // to ensure the HTML-to-Delta converter picks up the color attribute.
        html = html.replaceAllMapped(
          RegExp(r'<(h[1-6]|p)([^>]*)style="([^"]*color:\s*(#[0-9a-f]{3,6}|rgb\([^\)]+\))[^"]*)"([^>]*)>(.*?)</\1>', 
          caseSensitive: false, dotAll: true),
          (match) {
            String tag = match.group(1)!;
            String attr1 = match.group(2)!;
            String style = match.group(3)!;
            String attr2 = match.group(4)!;
            String content = match.group(5)!;
            
            // Extract the specific color value
            RegExp colorReg = RegExp(r'color:\s*(#[0-9a-f]{3,6}|rgb\([^\)]+\))', caseSensitive: false);
            String colorValue = colorReg.firstMatch(style)?.group(1) ?? '';
            
            if (colorValue.isNotEmpty) {
              return '<$tag$attr1 style="$style"$attr2><span style="color: $colorValue">$content</span></$tag>';
            }
            return match.group(0)!;
          }
        );

        // Convert HTML -> Delta
        var delta = HtmlToDelta().convert(html);

        // Post-process Delta to convert LaTeX strings to math embeds
        delta = _processMathEmbeds(delta);

        _controller = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _controller = quill.QuillController.basic();
      }
    } catch (e) {
      debugPrint('Error initializing editor with HTML: $e');
      final doc = quill.Document();
      if (widget.initialHtml != null) {
        doc.insert(0, widget.initialHtml!);
      }
      _controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    _controller.addListener(_onContentChanged);
  }

  quill_delta.Delta _processMathEmbeds(quill_delta.Delta delta) {
    final newDelta = quill_delta.Delta();
    for (final op in delta.toList()) {
      if (op.key == 'insert' && op.value is String) {
        final text = op.value as String;
        final matches = MathUtils.latexRegex.allMatches(text);

        if (matches.isEmpty) {
          newDelta.push(op);
          continue;
        }

        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            newDelta.insert(
                text.substring(lastIndex, match.start), op.attributes);
          }

          final rawMatch = match.group(0)!;
          final cleanLatex = _stripMathDelimiters(rawMatch);

          newDelta.insert(
            quill.BlockEmbed.custom(quill.CustomBlockEmbed('math', cleanLatex)),
            op.attributes,
          );
          lastIndex = match.end;
        }

        if (lastIndex < text.length) {
          newDelta.insert(text.substring(lastIndex), op.attributes);
        }
      } else {
        newDelta.push(op);
      }
    }
    return newDelta;
  }

  String _stripMathDelimiters(String token) {
    if (token.startsWith(r'\[') && token.endsWith(r'\]')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith(r'\(') && token.endsWith(r'\)')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$\$') && token.endsWith('\$\$')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$') && token.endsWith('\$')) {
      return token.substring(1, token.length - 1);
    }
    return token;
  }

  void _onContentChanged() {
    final delta = _controller.document.toDelta();
    final deltaJson = List<Map<String, dynamic>>.from(delta.toJson());

    // Pre-process Delta ops to convert 'math' embeds to HTML-friendly LaTeX strings
    for (var op in deltaJson) {
      if (op['insert'] is Map && op['insert']['math'] != null) {
        final latex = op['insert']['math'];
        op['insert'] = '\\($latex\\)';
      }
    }

    final converter = QuillDeltaToHtmlConverter(
      deltaJson,
      ConverterOptions(
        converterOptions: OpConverterOptions(
          inlineStylesFlag: true,
        ),
      ),
    );

    final html = converter.convert();
    if (mounted) {
      setState(() {});
    }
    widget.onContentChanged(html);
  }

  bool _hasInlineStyle(quill.Attribute attribute) {
    return _selectionStyle.attributes.containsKey(attribute.key);
  }

  void _toggleInlineStyle(quill.Attribute attribute) {
    _focusNode.requestFocus();
    final isActive = _selectionStyle.attributes.containsKey(attribute.key);
    _controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  void _toggleDirection() {
    _focusNode.requestFocus();
    final current = _selectionStyle.attributes[quill.Attribute.direction.key];
    final isRtl = current?.value == quill.Attribute.rtl.value;
    _controller.formatSelection(
      isRtl
          ? quill.Attribute.clone(quill.Attribute.rtl, null)
          : quill.Attribute.rtl,
    );
  }

  void _toggleAlignment(quill.Attribute attribute) {
    _focusNode.requestFocus();
    final current = _selectionStyle.attributes[quill.Attribute.align.key];
    final isSame = current?.value == attribute.value;
    _controller.formatSelection(
      isSame ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  void _toggleBlockAttribute(quill.Attribute attribute) {
    _focusNode.requestFocus();
    final current = _selectionStyle.attributes[attribute.key];
    final isSame = current?.value == attribute.value;
    _controller.formatSelection(
      isSame ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  void _applyColor(Color? color) {
    _focusNode.requestFocus();
    if (color == null) {
      _controller.formatSelection(quill.Attribute.clone(quill.Attribute.color, null));
    } else {
      _controller.formatSelection(
        quill.Attribute.fromKeyValue(
          quill.Attribute.color.key,
          _toHexColor(color),
        )!,
      );
    }
  }

  void _applyBackground(Color? color) {
    _focusNode.requestFocus();
    if (color == null) {
      _controller.formatSelection(quill.Attribute.clone(quill.Attribute.background, null));
    } else {
      _controller.formatSelection(
        quill.Attribute.fromKeyValue(
          quill.Attribute.background.key,
          _toHexColor(color),
        )!,
      );
    }
  }

  void _clearFormatting() {
    _focusNode.requestFocus();
    for (final attribute in _selectionStyle.attributes.values) {
      _controller.formatSelection(quill.Attribute.clone(attribute, null));
    }
  }

  Future<void> _insertOrEditLink() async {
    _focusNode.requestFocus();
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }

    final existingLink =
        _selectionStyle.attributes[quill.Attribute.link.key]?.value?.toString();
    final linkController = TextEditingController(text: existingLink ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة رابط'),
        content: TextField(
          controller: linkController,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('إزالة الرابط'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, linkController.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result.isEmpty) {
      _controller
          .formatSelection(quill.Attribute.clone(quill.Attribute.link, null));
      return;
    }

    final normalized =
        result.startsWith('http://') || result.startsWith('https://')
            ? result
            : 'https://$result';
    _controller.formatSelection(quill.LinkAttribute(normalized));
  }

  String _toHexColor(Color color) {
    // Ensure we get a 6-character hex string without alpha channel
    return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  Widget _buildToolbarButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isSelected,
    String? tooltip,
  }) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final foreground = isSelected
        ? Colors.white
        : (isDark ? Colors.white : AppColors.getTextColor(context));
    final background = isSelected ? AppColors.brandPrimary : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          minimumSize: const Size(34, 34),
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarMenuButton<T>({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required List<PopupMenuEntry<T>> items,
    required void Function(T value) onSelected,
    bool isSelected = false,
  }) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final foreground = isSelected
        ? Colors.white
        : (isDark ? Colors.white : AppColors.getTextColor(context));
    final background = isSelected ? AppColors.brandPrimary : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        onSelected: onSelected,
        offset: const Offset(0, 40),
        color: isDark ? AppColors.getSurfaceColor(context) : Colors.white,
        itemBuilder: (_) => items,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }

  Widget _buildColorPickerMenu({
    required BuildContext context,
    required bool isBackground,
    required bool isActive,
    required void Function(Color?) onSelected,
  }) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    return PopupMenuButton<Color?>(
      tooltip: isBackground ? 'لون الخلفية' : 'لون النص',
      onSelected: onSelected,
      offset: const Offset(0, 40),
      color: isDark ? AppColors.getSurfaceColor(context) : Colors.white,
      itemBuilder: (context) => [
        PopupMenuItem<Color?>(
          value: null,
          child: Row(
            children: [
              const Icon(Icons.format_color_reset, size: 18),
              const SizedBox(width: 12),
              Text(isBackground ? 'بلا لون (شفاف)' : 'تلقائي (بلا لون)'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<Color?>(
          enabled: false,
          child: SizedBox(
            width: 210,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _toolbarColors.map((color) {
                return InkWell(
                  onTap: () {
                    onSelected(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isBackground ? Icons.format_color_fill : Icons.format_color_text,
          size: 18,
          color: isActive ? Colors.white : (isDark ? Colors.white : AppColors.getTextColor(context)),
        ),
      ),
    );
  }

  PopupMenuItem<T> _menuItem<T>(T value, String label, {Widget? trailing}) {
    return PopupMenuItem<T>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (trailing != null) trailing,
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextToolbar(BuildContext context) {
    final alignAttribute =
        _selectionStyle.attributes[quill.Attribute.align.key];
    final directionAttribute =
        _selectionStyle.attributes[quill.Attribute.direction.key];
    final headerAttribute =
        _selectionStyle.attributes[quill.Attribute.header.key];
    final listAttribute = _selectionStyle.attributes[quill.Attribute.list.key];
    final linkActive =
        _selectionStyle.attributes.containsKey(quill.Attribute.link.key);
    final colorActive =
        _selectionStyle.attributes.containsKey(quill.Attribute.color.key);
    final backgroundActive =
        _selectionStyle.attributes.containsKey(quill.Attribute.background.key);
    final sizeAttribute = _selectionStyle.attributes[quill.Attribute.size.key];
    final scriptAttribute = _selectionStyle.attributes[quill.Attribute.script.key];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _buildToolbarButton(
            context: context,
            icon: Icons.format_bold,
            tooltip: 'عريض',
            isSelected: _hasInlineStyle(quill.Attribute.bold),
            onPressed: () => _toggleInlineStyle(quill.Attribute.bold),
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_italic,
            tooltip: 'مائل',
            isSelected: _hasInlineStyle(quill.Attribute.italic),
            onPressed: () => _toggleInlineStyle(quill.Attribute.italic),
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_underline,
            tooltip: 'تحته خط',
            isSelected: _hasInlineStyle(quill.Attribute.underline),
            onPressed: () => _toggleInlineStyle(quill.Attribute.underline),
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_strikethrough,
            tooltip: 'يتوسطه خط',
            isSelected: _hasInlineStyle(quill.Attribute.strikeThrough),
            onPressed: () => _toggleInlineStyle(quill.Attribute.strikeThrough),
          ),
          const VerticalDivider(width: 12, thickness: 1, indent: 8, endIndent: 8),
          _buildToolbarButton(
            context: context,
            icon: Icons.superscript,
            tooltip: 'أس علوي',
            isSelected: scriptAttribute?.value == 'super',
            onPressed: () => _toggleInlineStyle(quill.Attribute.superscript),
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.subscript,
            tooltip: 'أس سفلي',
            isSelected: scriptAttribute?.value == 'sub',
            onPressed: () => _toggleInlineStyle(quill.Attribute.subscript),
          ),
          const VerticalDivider(width: 12, thickness: 1, indent: 8, endIndent: 8),
          _buildToolbarMenuButton<String>(
            context: context,
            icon: Icons.format_size,
            tooltip: 'حجم الخط',
            isSelected: sizeAttribute != null,
            onSelected: (value) {
              if (value == 'normal') {
                _controller.formatSelection(quill.Attribute.fromKeyValue('size', null));
              } else {
                _controller.formatSelection(quill.Attribute.fromKeyValue('size', value));
              }
            },
            items: [
              _menuItem('small', 'صغير'),
              _menuItem('normal', 'عادي'),
              _menuItem('large', 'كبير'),
              _menuItem('huge', 'ضخم للغاية'),
            ],
          ),
          _buildToolbarMenuButton<String>(
            context: context,
            icon: Icons.title,
            tooltip: 'العناوين',
            isSelected: headerAttribute != null,
            onSelected: (value) {
              switch (value) {
                case 'normal':
                  _controller.formatSelection(quill.Attribute.header);
                  break;
                case 'h1':
                  _toggleBlockAttribute(quill.Attribute.h1);
                  break;
                case 'h2':
                  _toggleBlockAttribute(quill.Attribute.h2);
                  break;
                case 'h3':
                  _toggleBlockAttribute(quill.Attribute.h3);
                  break;
              }
            },
            items: [
              _menuItem('normal', 'نص عادي'),
              _menuItem('h1', 'عنوان 1'),
              _menuItem('h2', 'عنوان 2'),
              _menuItem('h3', 'عنوان 3'),
            ],
          ),
          _buildToolbarMenuButton<String>(
            context: context,
            icon: Icons.format_list_bulleted,
            tooltip: 'القوائم',
            isSelected: listAttribute != null,
            onSelected: (value) {
              switch (value) {
                case 'bullet':
                  _toggleBlockAttribute(quill.Attribute.ul);
                  break;
                case 'ordered':
                  _toggleBlockAttribute(quill.Attribute.ol);
                  break;
                case 'check':
                  _toggleBlockAttribute(quill.Attribute.unchecked);
                  break;
              }
            },
            items: [
              _menuItem('bullet', 'تعداد نقطي'),
              _menuItem('ordered', 'تعداد رقمي'),
              _menuItem('check', 'قائمة مهام'),
            ],
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_align_right,
            tooltip: 'محاذاة يمين',
            isSelected:
                alignAttribute?.value == quill.Attribute.rightAlignment.value,
            onPressed: () => _toggleAlignment(quill.Attribute.rightAlignment),
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_align_center,
            tooltip: 'توسيط',
            isSelected:
                alignAttribute?.value == quill.Attribute.centerAlignment.value,
            onPressed: () => _toggleAlignment(quill.Attribute.centerAlignment),
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_align_left,
            tooltip: 'محاذاة يسار',
            isSelected:
                alignAttribute?.value == quill.Attribute.leftAlignment.value,
            onPressed: () => _toggleAlignment(quill.Attribute.leftAlignment),
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_textdirection_r_to_l,
            tooltip: 'اتجاه النص',
            isSelected: directionAttribute?.value == quill.Attribute.rtl.value,
            onPressed: _toggleDirection,
          ),          _buildColorPickerMenu(
            context: context,
            isBackground: false,
            isActive: colorActive,
            onSelected: _applyColor,
          ),
          _buildColorPickerMenu(
            context: context,
            isBackground: true,
            isActive: backgroundActive,
            onSelected: _applyBackground,
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.link,
            tooltip: 'رابط',
            isSelected: linkActive,
            onPressed: _insertOrEditLink,
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.format_clear,
            tooltip: 'مسح التنسيق',
            isSelected: false,
            onPressed: _clearFormatting,
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.undo,
            tooltip: 'تراجع',
            isSelected: false,
            onPressed: _controller.undo,
          ),
          _buildToolbarButton(
            context: context,
            icon: Icons.redo,
            tooltip: 'إعادة',
            isSelected: false,
            onPressed: _controller.redo,
          ),
        ],
      ),
    );
  }


  static const List<Color> _toolbarColors = [
    Colors.black, Colors.white, Colors.grey,
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
    Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
    Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
    Colors.brown, Colors.blueGrey,
  ];

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use ThemeProvider as the single source of truth for dark mode.
    // Theme.of(context).brightness can mismatch when parent screens apply
    // their own admin theme wrappers.
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final baseStyles = quill.DefaultStyles.getInstance(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.getSurfaceColor(context) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused
                  ? AppColors.brandPrimary
                  : AppColors.getBorderColor(context),
              width: _isFocused ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.05),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTextToolbar(context),
                        Container(
                          height: 1,
                          color: AppColors.getBorderColor(context)
                              .withValues(alpha: 0.5),
                        ),
                        MathSymbolToolbar(
                          onSymbolSelected: (symbol) {
                            _focusNode.requestFocus();
                            Future.delayed(const Duration(milliseconds: 50),
                                () {
                              if (!mounted) return;
                              final index = _controller.selection.extentOffset;
                              final length = _controller.selection.end -
                                  _controller.selection.start;
                              final insertIndex = index >= 0
                                  ? index
                                  : (_controller.document.length - 1)
                                      .clamp(0, 999999);
                              if (symbol.contains('\\') ||
                                  symbol.startsWith(r'\(') ||
                                  symbol.contains('^') ||
                                  symbol.contains('_')) {
                                // Clean the latex (remove delimiters if any)
                                String cleanLatex = symbol;
                                if (cleanLatex.startsWith(r'\(') &&
                                    cleanLatex.endsWith(r'\)')) {
                                  cleanLatex = cleanLatex.substring(
                                      2, cleanLatex.length - 2);
                                } else if (cleanLatex.startsWith(r'\[') &&
                                    cleanLatex.endsWith(r'\]')) {
                                  cleanLatex = cleanLatex.substring(
                                      2, cleanLatex.length - 2);
                                }

                                _controller.replaceText(
                                  insertIndex,
                                  length > 0 ? length : 0,
                                  quill.BlockEmbed.custom(
                                    quill.CustomBlockEmbed('math', cleanLatex),
                                  ),
                                  null,
                                );
                              } else {
                                // Plain symbol insert
                                _controller.replaceText(
                                  insertIndex,
                                  length > 0 ? length : 0,
                                  symbol,
                                  null,
                                );
                              }
                              _controller.updateSelection(
                                TextSelection.collapsed(
                                  offset: insertIndex +
                                      (symbol.contains('\\')
                                          ? 1
                                          : symbol.length),
                                ),
                                quill.ChangeSource.local,
                              );
                            });
                          },
                        ),
                        Container(
                          height: 1,
                          color: AppColors.getBorderColor(context)
                              .withValues(alpha: 0.5),
                        ),
                      ],
                    )),
                Container(
                  constraints: BoxConstraints(
                    minHeight: widget.height,
                    maxHeight: widget.height,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.15)
                      : Colors.transparent,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _focusNode.requestFocus,
                    child: quill.QuillEditor(
                      controller: _controller,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      config: quill.QuillEditorConfig(
                        placeholder: widget.placeholder,
                        padding: const EdgeInsets.all(12),
                        expands: false,
                        scrollable: true,
                        autoFocus: false,
                        minHeight: widget.height,
                        maxHeight: widget.height,
                        onTapOutside: (_, focusNode) => focusNode.unfocus(),
                        embedBuilders: [
                          MathEmbedBuilder(),
                        ],
                        customStyles: quill.DefaultStyles(
                          h1: baseStyles.h1?.copyWith(
                            style: baseStyles.h1!.style.copyWith(color: null),
                          ),
                          h2: baseStyles.h2?.copyWith(
                            style: baseStyles.h2!.style.copyWith(color: null),
                          ),
                          h3: baseStyles.h3?.copyWith(
                            style: baseStyles.h3!.style.copyWith(color: null),
                          ),
                          lineHeightNormal: baseStyles.lineHeightNormal,
                          lineHeightTight: baseStyles.lineHeightTight,
                          lineHeightOneAndHalf: baseStyles.lineHeightOneAndHalf,
                          lineHeightDouble: baseStyles.lineHeightDouble,
                          bold: baseStyles.bold,
                          subscript: baseStyles.subscript,
                          superscript: baseStyles.superscript,
                          italic: baseStyles.italic,
                          small: baseStyles.small,
                          underline: baseStyles.underline,
                          strikeThrough: baseStyles.strikeThrough,
                          inlineCode: baseStyles.inlineCode,
                          link: baseStyles.link,
                          // color: defaultTextColor, // Removed global override to fix custom color persistence
                          lists: baseStyles.lists,
                          quote: baseStyles.quote,
                          code: baseStyles.code,
                          indent: baseStyles.indent,
                          align: baseStyles.align,
                          leading: baseStyles.leading,
                          sizeSmall: baseStyles.sizeSmall,
                          sizeLarge: baseStyles.sizeLarge,
                          sizeHuge: baseStyles.sizeHuge,
                          palette: baseStyles.palette,
                          placeHolder: (baseStyles.placeHolder ??
                                  quill.DefaultTextBlockStyle(
                                    const TextStyle(fontSize: 16),
                                    const quill.HorizontalSpacing(0, 0),
                                    const quill.VerticalSpacing(0, 0),
                                    const quill.VerticalSpacing(0, 0),
                                    null,
                                  ))
                              .copyWith(
                            style: (baseStyles.placeHolder?.style ??
                                    const TextStyle(fontSize: 16))
                                .copyWith(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 16,
                            ),
                          ),
                          paragraph: (baseStyles.paragraph ??
                                  quill.DefaultTextBlockStyle(
                                    const TextStyle(fontSize: 16, height: 1.5),
                                    const quill.HorizontalSpacing(0, 0),
                                    const quill.VerticalSpacing(0, 0),
                                    const quill.VerticalSpacing(0, 0),
                                    null,
                                  ))
                              .copyWith(
                            style: (baseStyles.paragraph?.style ??
                                    const TextStyle(fontSize: 16, height: 1.5))
                                .copyWith(
                              // color: defaultTextColor, // Removed to allow custom colors to show in editor
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
