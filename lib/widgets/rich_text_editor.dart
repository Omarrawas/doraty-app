import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
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
    if (mounted && _focusNode.hasFocus) {
      setState(() {
        _isFocused = true;
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
      // Fallback to plain text if HTML conversion fails
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
    // extract delta
    final delta = _controller.document.toDelta();

    // convert to html
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
    return TapRegion(
      groupId: 'rich_text_editor_group',
      onTapOutside: (event) {
        // Only unfocus if we are actually focused and the tap is truly outside
        if (_isFocused) {
          setState(() {
            _isFocused = false;
          });
          _focusNode.unfocus();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar container
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: Colors.black12.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.black87, size: 20),
                    child: quill.QuillSimpleToolbar(
                      controller: _controller,
                      config: quill.QuillSimpleToolbarConfig(
                        multiRowsDisplay: true,
                        showSearchButton: false,
                        showFontFamily: false,
                        showFontSize: true,
                        showHeaderStyle: false,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showStrikeThrough: true,
                        showInlineCode: false,
                        showColorButton: true,
                        showBackgroundColorButton: true,
                        showClearFormat: true,
                        showAlignmentButtons: true,
                        showLeftAlignment: true,
                        showCenterAlignment: true,
                        showRightAlignment: true,
                        showJustifyAlignment: true,
                        showListNumbers: true,
                        showListBullets: true,
                        showListCheck: false,
                        showCodeBlock: false,
                        showQuote: false,
                        showIndent: false,
                        showLink: false,
                        showUndo: true,
                        showRedo: true,
                        showDirection: true,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.black12),
                MathSymbolToolbar(
                  onSymbolSelected: (symbol) {
                    final index = _controller.selection.extentOffset;
                    final length =
                        _controller.selection.end - _controller.selection.start;

                    _controller.replaceText(
                      index >= 0 ? index : 0,
                      length > 0 ? length : 0,
                      symbol,
                      null,
                    );

                    int newOffset = (index >= 0 ? index : 0) + symbol.length;
                    if (symbol.contains('{}')) {
                      newOffset =
                          (index >= 0 ? index : 0) + symbol.indexOf('{}') + 1;
                    } else if (symbol.contains('[]')) {
                      newOffset =
                          (index >= 0 ? index : 0) + symbol.indexOf('[]') + 1;
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
              ],
            ),
          ),
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: _isFocused
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.2),
                width: _isFocused ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: quill.QuillEditor.basic(
              controller: _controller,
              focusNode: _focusNode,
              config: quill.QuillEditorConfig(
                placeholder: widget.placeholder,
                padding: const EdgeInsets.all(12),
                expands: false,
                scrollable: true,
                customStyles: const quill.DefaultStyles(
                  paragraph: quill.DefaultTextBlockStyle(
                    TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.3,
                    ),
                    quill.HorizontalSpacing(0, 0),
                    quill.VerticalSpacing(0, 0),
                    quill.VerticalSpacing(0, 0),
                    null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
