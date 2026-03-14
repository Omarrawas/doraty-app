import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import '../../core/theme/app_colors.dart';
import 'math_symbol_toolbar.dart';

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
    final converter = QuillDeltaToHtmlConverter(
      delta.toJson(),
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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused
                    ? AppColors.primaryPurple
                    : (isDark ? Colors.white12 : Colors.black12),
                width: 1.5,
              ),
              boxShadow: [
                if (_isFocused)
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                                      color: AppColors.primaryPurple,
                                      style: IconButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: AppColors.primaryPurple,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: Colors.black12),
                          MathSymbolToolbar(
                            onSymbolSelected: (symbol) {
                              final index = _controller.selection.extentOffset;
                              final length = _controller.selection.end -
                                  _controller.selection.start;

                              _controller.replaceText(
                                index >= 0 ? index : 0,
                                length > 0 ? length : 0,
                                symbol,
                                null,
                              );

                              int newOffset =
                                  (index >= 0 ? index : 0) + symbol.length;
                              if (symbol.contains('{}')) {
                                newOffset = (index >= 0 ? index : 0) +
                                    symbol.indexOf('{}') +
                                    1;
                              } else if (symbol.contains('[]')) {
                                newOffset = (index >= 0 ? index : 0) +
                                    symbol.indexOf('[]') +
                                    1;
                              }

                              _controller.updateSelection(
                                TextSelection.collapsed(offset: newOffset),
                                quill.ChangeSource.local,
                              );

                              Future.delayed(Duration.zero, () {
                                if (mounted) {
                                  _focusNode.requestFocus();
                                }
                              });
                            },
                          ),
                          const Divider(height: 1, color: Colors.black12),
                        ],
                      ),
                    ),
                  ],
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
            ),
          ),
        ],
      ),
    );
  }
}
