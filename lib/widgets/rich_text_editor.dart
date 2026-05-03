import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_tex/flutter_tex.dart';
import '../../core/theme/app_colors.dart';
import 'math_symbol_toolbar.dart';

class MathEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'math';

  @override
  Widget build(quill.EmbedContext context) {
    final latex = context.node.value.data as String;
    final isDark = Theme.of(context.context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.getBorderColor(context.context).withValues(alpha: 0.3),
        ),
      ),
      child: TeXView(
        child: TeXViewDocument(
          '\\($latex\\)',
          style: TeXViewStyle(
            contentColor: isDark ? Colors.white : Colors.black87,
            textAlign: TeXViewTextAlign.center,
            padding: const TeXViewPadding.all(4),
          ),
        ),
        style: const TeXViewStyle(
          backgroundColor: Colors.transparent,
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
  bool _isFocused = false;
  String _currentHtml = '';

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
    final List<dynamic> deltaJson = delta.toJson();

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
    widget.onContentChanged(html);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TapRegion(
      onTapOutside: (event) {
        if (_isFocused) {
          _focusNode.unfocus();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.getSurfaceColor(context)
                  : Colors.white,
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
                  if (_isFocused) ...[
                    Container(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.05),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          quill.QuillSimpleToolbar(
                            controller: _controller,
                            config: quill.QuillSimpleToolbarConfig(
                              multiRowsDisplay: false,
                              showSearchButton: false,
                              showFontFamily: false,
                              showFontSize: true,
                              showHeaderStyle: false,
                              showBoldButton: true,
                              showItalicButton: true,
                              showUnderLineButton: true,
                              showStrikeThrough: false,
                              showInlineCode: false,
                              showColorButton: true,
                              showBackgroundColorButton: true,
                              showClearFormat: true,
                              showAlignmentButtons: false,
                              showLeftAlignment: true,
                              showCenterAlignment: true,
                              showRightAlignment: true,
                              showJustifyAlignment: true,
                              showListNumbers: false,
                              showListBullets: false,
                              showListCheck: false,
                              showCodeBlock: false,
                              showQuote: false,
                              showIndent: false,
                              showLink: false,
                              showUndo: true,
                              showRedo: true,
                              showDirection: true,
                              buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                                base: quill.QuillToolbarBaseButtonOptions(
                                  iconTheme: quill.QuillIconTheme(
                                    iconButtonSelectedData: quill.IconButtonData(
                                      color: AppColors.brandPrimary,
                                      style: IconButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: AppColors.brandPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            color: AppColors.getBorderColor(context).withValues(alpha: 0.5),
                          ),
                          MathSymbolToolbar(
                            onSymbolSelected: (symbol) {
                              _focusNode.requestFocus();
                              Future.delayed(const Duration(milliseconds: 50), () {
                                if (!mounted) return;
                                final index = _controller.selection.extentOffset;
                                final length = _controller.selection.end - _controller.selection.start;
                                final insertIndex = index >= 0 ? index : (_controller.document.length - 1).clamp(0, 999999);
                                if (symbol.contains('\\') || symbol.startsWith(r'\(')) {
                                  String cleanLatex = symbol;
                                  if (cleanLatex.startsWith(r'\(') && cleanLatex.endsWith(r'\)')) {
                                    cleanLatex = cleanLatex.substring(2, cleanLatex.length - 2);
                                  }
                                  _controller.replaceText(
                                    insertIndex,
                                    length > 0 ? length : 0,
                                    quill.BlockEmbed.custom(quill.CustomBlockEmbed('math', cleanLatex)),
                                    null,
                                  );
                                } else {
                                  _controller.replaceText(insertIndex, length > 0 ? length : 0, symbol, null);
                                }
                                _controller.updateSelection(TextSelection.collapsed(offset: insertIndex + 1), quill.ChangeSource.local);
                              });
                            },
                          ),
                          Container(
                            height: 1,
                            color: AppColors.getBorderColor(context).withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Column(
                    children: [
                      Container(
                        height: widget.height,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        color: isDark ? Colors.transparent : Colors.white,
                        child: quill.QuillEditor.basic(
                          controller: _controller,
                          focusNode: _focusNode,
                          config: quill.QuillEditorConfig(
                            placeholder: widget.placeholder,
                            padding: const EdgeInsets.all(12),
                            expands: false,
                            scrollable: true,
                            autoFocus: false,
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
                                  color: widget.textColor ?? (isDark ? Colors.white : Colors.black87),
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
