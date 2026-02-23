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
      onTapOutside: (event) {
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
          Visibility(
            visible: _isFocused,
            maintainState: true,
            maintainAnimation: true,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Column(
                children: [
                  quill.QuillSimpleToolbar(
                    controller: _controller,
                    config: quill.QuillSimpleToolbarConfig(
                      multiRowsDisplay: false,
                      showSearchButton: false,
                      showFontFamily: false,
                      showFontSize: !widget.isCompact,
                      buttonOptions:
                          const quill.QuillSimpleToolbarButtonOptions(
                        fontSize: quill.QuillToolbarFontSizeButtonOptions(
                          items: {
                            'small': '10',
                            'large': '18',
                            'huge': '32',
                            'clear': '14'
                          },
                        ),
                      ),
                      showHeaderStyle: false, // Hide headings to save space
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showStrikeThrough: !widget.isCompact,
                      showInlineCode: false,
                      showColorButton: true,
                      showBackgroundColorButton: true,
                      showClearFormat: !widget.isCompact,
                      showAlignmentButtons: true,
                      showLeftAlignment: true,
                      showCenterAlignment: true,
                      showRightAlignment: true,
                      showJustifyAlignment: true,
                      showListNumbers: !widget.isCompact,
                      showListBullets: !widget.isCompact,
                      showListCheck: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: false,
                      showLink: false,
                      showUndo: false,
                      showRedo: false,
                      showDirection: true,
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black12),
                  MathSymbolToolbar(
                    onSymbolSelected: (symbol) {
                      final index = _controller.selection.extentOffset;
                      final length = _controller.selection.end -
                          _controller.selection.start;
                      
                      // Using the raw LaTeX symbol directly for better rendering
                      _controller.replaceText(
                        index >= 0 ? index : 0,
                        length > 0 ? length : 0,
                        symbol,
                        null,
                      );

                      // Move cursor after the inserted symbol (or inside if it's a template)
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

                      // Use a small delay to ensure the popup is fully closed before requesting focus
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
      ), // End of Column
    ); // End of TapRegion
  }
}
