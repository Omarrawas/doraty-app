import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'math_symbol_toolbar.dart';

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
        // Convert HTML -> Delta
        final delta = HtmlToDelta().convert(widget.initialHtml!);
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
      ConverterOptions.forEmail(),
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

  void _applyColor(Color color) {
    _focusNode.requestFocus();
    _controller.formatSelection(
      quill.Attribute.fromKeyValue(
        quill.Attribute.color.key,
        _toHexColor(color),
      )!,
    );
  }

  void _applyBackground(Color color) {
    _focusNode.requestFocus();
    _controller.formatSelection(
      quill.Attribute.fromKeyValue(
        quill.Attribute.background.key,
        _toHexColor(color),
      )!,
    );
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
    final rgb = color.value & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
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
          ),
          _buildToolbarMenuButton<Color>(
            context: context,
            icon: Icons.format_color_text,
            tooltip: 'لون النص',
            isSelected: colorActive,
            onSelected: _applyColor,
            items: _toolbarColors
                .map((color) => _menuItem(
                      color,
                      _colorName(color),
                      trailing: CircleAvatar(backgroundColor: color, radius: 8),
                    ))
                .toList(),
          ),
          _buildToolbarMenuButton<Color>(
            context: context,
            icon: Icons.format_color_fill,
            tooltip: 'لون الخلفية',
            isSelected: backgroundActive,
            onSelected: _applyBackground,
            items: _toolbarColors
                .map((color) => _menuItem(
                      color,
                      _colorName(color),
                      trailing: CircleAvatar(backgroundColor: color, radius: 8),
                    ))
                .toList(),
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

  String _colorName(Color color) {
    if (color == Colors.black) return 'أسود';
    if (color == Colors.red) return 'أحمر';
    if (color == Colors.blue) return 'أزرق';
    if (color == Colors.green) return 'أخضر';
    if (color == Colors.orange) return 'برتقالي';
    if (color == Colors.purple) return 'بنفسجي';
    if (color == Colors.yellow) return 'أصفر';
    return 'لون';
  }

  static const List<Color> _toolbarColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
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
                                  symbol.startsWith(r'\(')) {
                                String cleanLatex = symbol;
                                if (cleanLatex.startsWith(r'\(') &&
                                    cleanLatex.endsWith(r'\)')) {
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
                          placeHolder: quill.DefaultTextBlockStyle(
                            TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 16,
                            ),
                            const quill.HorizontalSpacing(0, 0),
                            const quill.VerticalSpacing(0, 0),
                            const quill.VerticalSpacing(0, 0),
                            null,
                          ),
                          paragraph: quill.DefaultTextBlockStyle(
                            TextStyle(
                              color: widget.textColor ??
                                  (isDark ? Colors.white : Colors.black87),
                              fontSize: 16,
                              height: 1.5,
                            ),
                            const quill.HorizontalSpacing(0, 0),
                            const quill.VerticalSpacing(0, 0),
                            const quill.VerticalSpacing(0, 0),
                            null,
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
