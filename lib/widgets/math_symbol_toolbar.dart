import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:flutter_tex/flutter_tex.dart';

class MathSymbolToolbar extends StatelessWidget {
  final Function(String) onSymbolSelected;
  final ScrollController? scrollController;

  const MathSymbolToolbar({
    super.key,
    required this.onSymbolSelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? Color(0xFF1E1E1E) : Color(0xFFF3F3F3);
    final border = isDark ? Colors.white12 : Color(0xFFD0D0D0);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: background,
        gradient: LinearGradient(
          colors: [
            background.withValues(alpha: 0.98),
            background.withValues(alpha: 0.9),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          // ── Quick Equation Insert (Word-like) ──
          _buildEquationButton(context),
          _buildCategoryMenu(
            context,
            'الرموز',
            'αΩ',
            [
              _MathItem('α', 'ألفا', 'α'),
              _MathItem('β', 'بيتا', 'β'),
              _MathItem('γ', 'غاما', 'γ'),
              _MathItem('δ', 'دلتا', 'δ'),
              _MathItem('ε', 'إبسيلون', 'ε'),
              _MathItem('ζ', 'زيتا', 'ζ'),
              _MathItem('η', 'إيتا', 'η'),
              _MathItem('θ', 'ثيتا', 'θ'),
              _MathItem('ι', 'أيوتا', 'ι'),
              _MathItem('κ', 'كابا', 'κ'),
              _MathItem('λ', 'لامدا', 'λ'),
              _MathItem('μ', 'ميو', 'μ'),
              _MathItem('ν', 'نيو', 'ν'),
              _MathItem('ξ', 'كسي', 'ξ'),
              _MathItem('π', 'باي', 'π'),
              _MathItem('ρ', 'رو', 'ρ'),
              _MathItem('σ', 'سيغما', 'σ'),
              _MathItem('τ', 'تاو', 'τ'),
              _MathItem('φ', 'فاي', 'φ'),
              _MathItem('χ', 'كاي', 'χ'),
              _MathItem('ψ', 'بساي', 'ψ'),
              _MathItem('ω', 'أوميغا', 'ω'),
              _MathItem('Δ', 'دلتا كبيرة', 'Δ'),
              _MathItem('Ω', 'أوميغا كبيرة', 'Ω'),
              _MathItem('Σ', 'سيغما كبيرة', 'Σ'),
              _MathItem('Φ', 'فاي كبيرة', 'Φ'),
              _MathItem('∞', 'لانهاية', '∞'),
              _MathItem('∂', 'اشتقاق جزئي', '∂'),
              _MathItem('∇', 'نابلا', '∇'),
              _MathItem('ℏ', 'ثابت بلانك', 'ℏ'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'كيمياء',
            '⇌',
            [
              // ─── Arrows & Reactions ───
              _MathItem('→', 'سهم تفاعل', '→'),
              _MathItem('⇌', 'تفاعل عكوس', '⇌'),
              _MathItem('⇀', 'سهم أمامي', '⇀'),
              _MathItem('↽', 'سهم عكسي', '↽'),
              _MathItem('↑', 'غاز متصاعد', '↑'),
              _MathItem('↓', 'راسب', '↓'),
              // ─── States of Matter ───
              _MathItem('(s)', 'حالة صلبة', '(s)'),
              _MathItem('(l)', 'حالة سائلة', '(l)'),
              _MathItem('(g)', 'حالة غازية', '(g)'),
              _MathItem('(aq)', 'محلول مائي', '(aq)'),
              // ─── Subscript Numbers ───
              _MathItem('₀', 'رقم سفلي 0', '₀'),
              _MathItem('₁', 'رقم سفلي 1', '₁'),
              _MathItem('₂', 'رقم سفلي 2', '₂'),
              _MathItem('₃', 'رقم سفلي 3', '₃'),
              _MathItem('₄', 'رقم سفلي 4', '₄'),
              _MathItem('₅', 'رقم سفلي 5', '₅'),
              _MathItem('₆', 'رقم سفلي 6', '₆'),
              _MathItem('₇', 'رقم سفلي 7', '₇'),
              _MathItem('₈', 'رقم سفلي 8', '₈'),
              _MathItem('₉', 'رقم سفلي 9', '₉'),
              // ─── Superscript Numbers & Signs ───
              _MathItem('⁰', 'رقم علوي 0', '⁰'),
              _MathItem('¹', 'رقم علوي 1', '¹'),
              _MathItem('²', 'رقم علوي 2', '²'),
              _MathItem('³', 'رقم علوي 3', '³'),
              _MathItem('⁴', 'رقم علوي 4', '⁴'),
              _MathItem('⁺', 'شحنة موجبة', '⁺'),
              _MathItem('⁻', 'شحنة سالبة', '⁻'),
              _MathItem('²⁺', 'شحنة 2+', '²⁺'),
              _MathItem('²⁻', 'شحنة 2-', '²⁻'),
              _MathItem('³⁺', 'شحنة 3+', '³⁺'),
              _MathItem('³⁻', 'شحنة 3-', '³⁻'),
              // ─── Common Formulas (quick insert) ───
              _MathItem('H₂O', 'ماء', 'H₂O'),
              _MathItem('CO₂', 'ثاني أكسيد الكربون', 'CO₂'),
              _MathItem('O₂', 'أكسجين', 'O₂'),
              _MathItem('N₂', 'نيتروجين', 'N₂'),
              _MathItem('H₂', 'هيدروجين', 'H₂'),
              _MathItem('Cl₂', 'كلور', 'Cl₂'),
              _MathItem('NaCl', 'كلوريد الصوديوم', 'NaCl'),
              _MathItem('NaOH', 'هيدروكسيد الصوديوم', 'NaOH'),
              _MathItem('HCl', 'حمض الهيدروكلوريك', 'HCl'),
              _MathItem('H₂SO₄', 'حمض الكبريتيك', 'H₂SO₄'),
              _MathItem('HNO₃', 'حمض النتريك', 'HNO₃'),
              _MathItem('NH₃', 'أمونيا', 'NH₃'),
              _MathItem('CaCO₃', 'كربونات الكالسيوم', 'CaCO₃'),
              _MathItem('CH₄', 'ميثان', 'CH₄'),
              _MathItem('C₂H₅OH', 'إيثانول', 'C₂H₅OH'),
              _MathItem('Fe₂O₃', 'أكسيد الحديد III', 'Fe₂O₃'),
              // ─── Ions ───
              _MathItem('SO₄²⁻', 'كبريتات', 'SO₄²⁻'),
              _MathItem('NO₃⁻', 'نترات', 'NO₃⁻'),
              _MathItem('CO₃²⁻', 'كربونات', 'CO₃²⁻'),
              _MathItem('PO₄³⁻', 'فوسفات', 'PO₄³⁻'),
              _MathItem('OH⁻', 'هيدروكسيد', 'OH⁻'),
              _MathItem('NH₄⁺', 'أمونيوم', 'NH₄⁺'),
              _MathItem('Na⁺', 'صوديوم', 'Na⁺'),
              _MathItem('Ca²⁺', 'كالسيوم', 'Ca²⁺'),
              _MathItem('Al³⁺', 'ألمنيوم', 'Al³⁺'),
              _MathItem('Fe²⁺', 'حديد II', 'Fe²⁺'),
              _MathItem('Fe³⁺', 'حديد III', 'Fe³⁺'),
              _MathItem('Cu²⁺', 'نحاس', 'Cu²⁺'),
              _MathItem('MnO₄⁻', 'برمنغنات', 'MnO₄⁻'),
              _MathItem('Cr₂O₇²⁻', 'ثنائي كرومات', 'Cr₂O₇²⁻'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'عمليات',
            '±÷',
            [
              _MathItem('±', 'زائد أو ناقص', '±'),
              _MathItem('∓', 'ناقص أو زائد', '∓'),
              _MathItem('×', 'ضرب', '×'),
              _MathItem('÷', 'قسمة', '÷'),
              _MathItem('·', 'ضرب (نقطة)', '·'),
              _MathItem('≠', 'لا يساوي', '≠'),
              _MathItem('≈', 'تقريبا', '≈'),
              _MathItem('≡', 'مطابق', '≡'),
              _MathItem('≤', 'أقل أو يساوي', '≤'),
              _MathItem('≥', 'أكبر أو يساوي', '≥'),
              _MathItem('≪', 'أصغر بكثير', '≪'),
              _MathItem('≫', 'أكبر بكثير', '≫'),
              _MathItem('∝', 'تتناسب مع', '∝'),
              _MathItem('∈', 'ينتمي إلى', '∈'),
              _MathItem('∉', 'لا ينتمي إلى', '∉'),
              _MathItem('⊂', 'مجموعة جزئية', '⊂'),
              _MathItem('⊃', 'مجموعة شاملة', '⊃'),
              _MathItem('∪', 'اتحاد', '∪'),
              _MathItem('∩', 'تقاطع', '∩'),
              _MathItem('∅', 'مجموعة فارغة', '∅'),
              _MathItem('∀', 'لكل', '∀'),
              _MathItem('∃', 'يوجد', '∃'),
              _MathItem('∴', 'إذن', '∴'),
              _MathItem('∵', 'لأن', '∵'),
              _MathItem('⊥', 'عمودي على', '⊥'),
              _MathItem('∥', 'يوازي', '∥'),
              _MathItem('∠', 'زاوية', '∠'),
              _MathItem('°', 'درجة', '°'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'أسهم',
            '→',
            [
              _MathItem('→', 'سهم لليمين', '→'),
              _MathItem('←', 'سهم لليسار', '←'),
              _MathItem('↔', 'سهم مزدوج', '↔'),
              _MathItem('⇒', 'يؤدي إلى', '⇒'),
              _MathItem('⇐', 'ينتج من', '⇐'),
              _MathItem('⇔', 'إذا وفقط إذا', '⇔'),
              _MathItem('↑', 'سهم للأعلى', '↑'),
              _MathItem('↓', 'سهم للأسفل', '↓'),
              _MathItem('⇌', 'توازن', '⇌'),
              _MathItem('⟶', 'سهم طويل', '⟶'),
              _MathItem('⟸', 'سهم طويل لليسار', '⟸'),
              _MathItem('⟹', 'سهم طويل لليمين', '⟹'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'أعداد',
            'x²',
            [
              // Superscripts
              _MathItem('⁰', 'أس 0', '⁰'),
              _MathItem('¹', 'أس 1', '¹'),
              _MathItem('²', 'أس 2', '²'),
              _MathItem('³', 'أس 3', '³'),
              _MathItem('⁴', 'أس 4', '⁴'),
              _MathItem('⁵', 'أس 5', '⁵'),
              _MathItem('⁶', 'أس 6', '⁶'),
              _MathItem('⁷', 'أس 7', '⁷'),
              _MathItem('⁸', 'أس 8', '⁸'),
              _MathItem('⁹', 'أس 9', '⁹'),
              _MathItem('⁺', 'علوي +', '⁺'),
              _MathItem('⁻', 'علوي -', '⁻'),
              _MathItem('⁼', 'علوي =', '⁼'),
              _MathItem('ⁿ', 'أس n', 'ⁿ'),
              _MathItem('ⁱ', 'أس i', 'ⁱ'),
              // Subscripts
              _MathItem('₀', 'سفلي 0', '₀'),
              _MathItem('₁', 'سفلي 1', '₁'),
              _MathItem('₂', 'سفلي 2', '₂'),
              _MathItem('₃', 'سفلي 3', '₃'),
              _MathItem('₄', 'سفلي 4', '₄'),
              _MathItem('₅', 'سفلي 5', '₅'),
              _MathItem('₆', 'سفلي 6', '₆'),
              _MathItem('₇', 'سفلي 7', '₇'),
              _MathItem('₈', 'سفلي 8', '₈'),
              _MathItem('₉', 'سفلي 9', '₉'),
              _MathItem('₊', 'سفلي +', '₊'),
              _MathItem('₋', 'سفلي -', '₋'),
              _MathItem('₌', 'سفلي =', '₌'),
              _MathItem('ₙ', 'سفلي n', 'ₙ'),
              _MathItem('ₓ', 'سفلي x', 'ₓ'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'دوال',
            'sin',
            [
              _MathItem('sin', 'جا', 'sin'),
              _MathItem('cos', 'جتا', 'cos'),
              _MathItem('tan', 'ظا', 'tan'),
              _MathItem('cot', 'ظتا', 'cot'),
              _MathItem('sec', 'قا', 'sec'),
              _MathItem('csc', 'قتا', 'csc'),
              _MathItem('sin⁻¹', 'جا عكسية', 'arcsin'),
              _MathItem('cos⁻¹', 'جتا عكسية', 'arccos'),
              _MathItem('tan⁻¹', 'ظا عكسية', 'arctan'),
              _MathItem('log', 'لوغاريتم', 'log'),
              _MathItem('ln', 'لوغاريتم طبيعي', 'ln'),
              _MathItem('lim', 'نهاية', 'lim'),
            ],
          ),
        ],
      ),
    );
  }

  /// ─── Equation Builder Button (Word-Like) ───
  Widget _buildEquationButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? Color(0xFF8AB4F8) : Color(0xFF0F6CBD);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () => _showEquationDialog(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.functions, color: accent, size: 24),
                  SizedBox(height: 2),
                  Text(
                    'معادلة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ─── Visual Equation Dialog (like MS Word) ───
  void _showEquationDialog(BuildContext context) {
    final controller = TextEditingController();
    String previewLatex = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(16),
            child: Container(
              constraints: BoxConstraints(maxWidth: 520, maxHeight: 600),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF0F6CBD).withValues(alpha: 0.1),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.functions,
                            color: Color(0xFF0F6CBD), size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إدراج معادلة رياضية',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Quick Templates ──
                          Text('قوالب سريعة:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _equationTemplates.map((t) {
                              return InkWell(
                                onTap: () {
                                  controller.text = t.latex;
                                  setDialogState(() => previewLatex = t.latex);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.grey.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    t.label,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          SizedBox(height: 16),

                          // ── LaTeX Input ──
                          Text('اكتب المعادلة بصيغة LaTeX:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 8),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: TextField(
                              controller: controller,
                              maxLines: 3,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    r'مثال: \frac{-b \pm \sqrt{b^2-4ac}}{2a}',
                                hintStyle: TextStyle(
                                    color: Colors.grey.withValues(alpha: 0.5),
                                    fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.withValues(alpha: 0.05),
                              ),
                              onChanged: (val) {
                                setDialogState(() => previewLatex = val);
                              },
                            ),
                          ),

                          SizedBox(height: 16),

                          // ── Live Preview ──
                          Text('المعاينة:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 8),
                          Container(
                            constraints: BoxConstraints(minHeight: 80),
                            decoration: BoxDecoration(
                              color: AppColors.getTextColor(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      Color(0xFF0F6CBD).withValues(alpha: 0.3)),
                            ),
                            child: previewLatex.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text(
                                        'ابدأ بالكتابة لرؤية المعاينة',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 13),
                                      ),
                                    ),
                                  )
                                : TeXView(
                                    child: TeXViewDocument(
                                      '\\($previewLatex\\)',
                                      style: TeXViewStyle(
                                        contentColor: Colors.black,
                                        fontStyle:
                                            TeXViewFontStyle(fontSize: 18),
                                        textAlign: TeXViewTextAlign.center,
                                        padding: const TeXViewPadding.all(16),
                                      ),
                                    ),
                                    style: TeXViewStyle(
                                      backgroundColor: Colors.white,
                                    ),
                                    loadingWidgetBuilder: (context) =>
                                        Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Actions ──
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('إلغاء'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: previewLatex.isEmpty
                              ? null
                              : () {
                                  final result = '\\(${controller.text}\\)';
                                  Navigator.pop(ctx);
                                  onSymbolSelected(result);
                                },
                          icon: Icon(Icons.add, size: 18),
                          label: Text('إدراج المعادلة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0F6CBD),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryMenu(
    BuildContext context,
    String label,
    String iconLabel,
    List<_MathItem> items,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? Color(0xFF2A2A2A) : Colors.white;
    final border = isDark ? Colors.white12 : Color(0xFFD0D0D0);
    final textPrimary = isDark ? Colors.white : Color(0xFF1B1B1B);
    final textSecondary = isDark ? Colors.white70 : Color(0xFF5C5C5C);
    final accent = isDark ? Color(0xFF8AB4F8) : Color(0xFF0F6CBD);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: PopupMenuButton<String>(
        onSelected: onSymbolSelected,
        offset: Offset(0, -8),
        elevation: 10,
        color: surface,
        constraints: BoxConstraints(maxHeight: 420, minWidth: 280),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        tooltip: label,
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            color: surface.withValues(alpha: isDark ? 0.9 : 1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      iconLabel,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        itemBuilder: (context) => items.map((item) {
          return PopupMenuItem<String>(
            value: item.value,
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 48,
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      item.preview,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// ─── Quick equation templates ───
  static final List<_EquationTemplate> _equationTemplates = [
    _EquationTemplate(r'\frac{a}{b}', 'كسر'),
    _EquationTemplate(r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}', 'صيغة تربيعية'),
    _EquationTemplate(r'\sqrt{x}', 'جذر تربيعي'),
    _EquationTemplate(r'\sqrt[n]{x}', 'جذر نوني'),
    _EquationTemplate(r'x^{n}', 'أس'),
    _EquationTemplate(r'x_{n}', 'دليل سفلي'),
    _EquationTemplate(r'\sum_{i=1}^{n} x_i', 'مجموع'),
    _EquationTemplate(r'\prod_{i=1}^{n} x_i', 'جداء'),
    _EquationTemplate(r'\int_{a}^{b} f(x) \, dx', 'تكامل محدد'),
    _EquationTemplate(r'\int f(x) \, dx', 'تكامل غير محدد'),
    _EquationTemplate(r'\lim_{x \to \infty} f(x)', 'نهاية'),
    _EquationTemplate(r'\frac{dy}{dx}', 'مشتقة'),
    _EquationTemplate(r'\frac{\partial f}{\partial x}', 'مشتقة جزئية'),
    _EquationTemplate(r'\log_{a} x', 'لوغاريتم'),
    _EquationTemplate(r'\binom{n}{k}', 'توافيق'),
    _EquationTemplate(
        r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}', 'مصفوفة 2×2'),
    _EquationTemplate(r'|\vec{A}|', 'متجه'),
    _EquationTemplate(r'\vec{F} = m\vec{a}', 'قانون نيوتن'),
    _EquationTemplate(r'E = mc^{2}', 'طاقة أينشتاين'),
    _EquationTemplate(r'a^2 + b^2 = c^2', 'فيثاغورس'),
    _EquationTemplate(r'e^{i\pi} + 1 = 0', 'أويلر'),
    _EquationTemplate(r'PV = nRT', 'قانون الغاز المثالي'),
  ];
}

class _MathItem {
  final String value;
  final String label;
  final String preview;

  _MathItem(this.value, this.label, this.preview);
}

class _EquationTemplate {
  final String latex;
  final String label;

  _EquationTemplate(this.latex, this.label);
}
