import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:ui';

class RichTextEditor extends StatefulWidget {
  final String? initialContent;
  final Function(String) onContentChanged;

  const RichTextEditor({
    super.key,
    this.initialContent,
    required this.onContentChanged,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late quill.QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();

    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      // Load initial content
      // Note: You'll need to convert HTML to Delta format
    }

    _controller.addListener(() {
      // Convert to HTML and notify parent
      final html = _controller.document.toPlainText();
      widget.onContentChanged(html);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: quill.QuillToolbar.simple(
                  configurations: quill.QuillSimpleToolbarConfigurations(
                    controller: _controller,
                    showAlignmentButtons: true,
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showListBullets: true,
                    showListNumbers: true,
                    showCodeBlock: true,
                    showQuote: true,
                    showLink: true,
                  ),
                ),
              ),
              // Editor
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: quill.QuillEditor.basic(
                    configurations: quill.QuillEditorConfigurations(
                      controller: _controller,
                      placeholder: 'اكتب محتوى الدرس هنا...',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
