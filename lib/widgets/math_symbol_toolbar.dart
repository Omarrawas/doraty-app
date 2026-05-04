import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:flutter_math_fork/flutter_math.dart';

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
    final background = AppColors.getSurfaceColor(context);
    final borderColor = AppColors.getBorderColor(context);

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0,
                2), // Changed to positive offset to avoid "silver line" at top
          ),
        ],
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: false, // Don't block the UI, but allow dragging
          child: ListView(
            scrollDirection: Axis.horizontal,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        ),
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
              colors: [
                accent.withValues(alpha: 0.15),
                accent.withValues(alpha: 0.05)
              ],
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
    String selectedCategoryId = _equationCategories.first.id;

    // Capture theme colors before showing the dialog to ensure consistency during rebuilds
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppColors.getSurfaceColor(context);
    final textColor = AppColors.getTextColor(context);
    final mutedTextColor = AppColors.getMutedTextColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final inputFillColor = AppColors.getInputFillColor(context);
    final accentColor =
        isDark ? const Color(0xFF8AB4F8) : const Color(0xFF0F6CBD);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.functions, color: accentColor, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إدراج معادلة رياضية',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: textColor.withValues(alpha: 0.6)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'واجهة إدراج المعادلات هنا أصبحت أقرب لطريقة مايكروسوفت وورد: اختر نوع البنية ثم اضغط القالب ليملأ صيغة LaTeX تلقائيًا.',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _equationCategories.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final category = _equationCategories[index];
                                final selected =
                                    category.id == selectedCategoryId;
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedCategoryId = category.id;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accentColor.withValues(alpha: 0.14)
                                          : inputFillColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? accentColor
                                            : borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          category.icon,
                                          size: 18,
                                          color: selected
                                              ? accentColor
                                              : textColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          category.label,
                                          style: TextStyle(
                                            color: selected
                                                ? accentColor
                                                : textColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._equationCategories
                              .firstWhere((c) => c.id == selectedCategoryId)
                              .groups
                              .map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    group.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width = constraints.maxWidth;
                                      final crossAxisCount = width > 760
                                          ? 4
                                          : width > 520
                                              ? 3
                                              : 2;
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: group.templates.length,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio:
                                              width > 760 ? 1.45 : 1.15,
                                        ),
                                        itemBuilder: (context, index) {
                                          final template =
                                              group.templates[index];
                                          return InkWell(
                                            onTap: () {
                                              controller.text = template.latex;
                                              setDialogState(() {
                                                previewLatex = template.latex;
                                              });
                                            },
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: inputFillColor,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: borderColor,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(
                                                    child: Center(
                                                      child: _SafeMathPreview(
                                                        latex: template.preview,
                                                        textColor: textColor,
                                                        mathSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    template.label,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (template.hint !=
                                                      null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      template.hint!,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: mutedTextColor,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),

                          Text('قوالب سريعة:',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _equationTemplates.take(8).map((t) {
                              return ActionChip(
                                onPressed: () {
                                  controller.text = t.latex;
                                  setDialogState(() => previewLatex = t.latex);
                                },
                                backgroundColor: inputFillColor,
                                side: BorderSide(color: borderColor),
                                label: Text(
                                  t.label,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // ── LaTeX Input ──
                          Text('اكتب المعادلة بصيغة LaTeX:',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: TextField(
                              controller: controller,
                              maxLines: 3,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    r'مثال: \frac{-b \pm \sqrt{b^2-4ac}}{2a}',
                                hintStyle: TextStyle(
                                    color:
                                        mutedTextColor.withValues(alpha: 0.5),
                                    fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: accentColor, width: 1.5),
                                ),
                                filled: true,
                                fillColor: inputFillColor,
                              ),
                              onChanged: (val) {
                                setDialogState(() => previewLatex = val);
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Live Preview ──
                          Text('المعاينة:',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            decoration: BoxDecoration(
                              color: inputFillColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3)),
                            ),
                            child: previewLatex.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        'ابدأ بالكتابة لرؤية المعاينة',
                                        style: TextStyle(
                                            color: mutedTextColor,
                                            fontSize: 13),
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: _SafeMathPreview(
                                        latex: previewLatex,
                                        textColor: textColor,
                                        mathSize: 22,
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: borderColor.withValues(alpha: 0.3))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('إلغاء',
                              style: TextStyle(color: accentColor)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: previewLatex.isEmpty
                              ? null
                              : () {
                                  final result = '\\(${controller.text}\\)';
                                  Navigator.pop(ctx);
                                  onSymbolSelected(result);
                                },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إدراج المعادلة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
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
    final surface = AppColors.getSurfaceColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final textPrimary = AppColors.getTextColor(context);
    final textSecondary = AppColors.getMutedTextColor(context);
    final accent = isDark ? const Color(0xFF8AB4F8) : const Color(0xFF0F6CBD);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: PopupMenuButton<String>(
        onSelected: onSymbolSelected,
        offset: const Offset(0, -8),
        elevation: 10,
        color: surface,
        constraints: const BoxConstraints(maxHeight: 420, minWidth: 280),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        tooltip: label,
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
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
                  const SizedBox(height: 1),
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
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
    _EquationTemplate(r'\frac{a}{b}', 'كسر', preview: r'\frac{\Box}{\Box}'),
    _EquationTemplate(
      r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}',
      'صيغة تربيعية',
      preview: r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}',
    ),
    _EquationTemplate(r'\sqrt{x}', 'جذر تربيعي', preview: r'\sqrt{\Box}'),
    _EquationTemplate(
      r'\sqrt[n]{x}',
      'جذر نوني',
      preview: r'\sqrt[n]{\Box}',
    ),
    _EquationTemplate(r'x^{n}', 'أس', preview: r'x^{\Box}'),
    _EquationTemplate(r'x_{n}', 'دليل سفلي', preview: r'x_{\Box}'),
    _EquationTemplate(
      r'\sum_{i=1}^{n} x_i',
      'مجموع',
      preview: r'\sum_{i=1}^{n} x_i',
    ),
    _EquationTemplate(
      r'\prod_{i=1}^{n} x_i',
      'جداء',
      preview: r'\prod_{i=1}^{n} x_i',
    ),
    _EquationTemplate(
      r'\int_{a}^{b} f(x) \, dx',
      'تكامل محدد',
      preview: r'\int_{a}^{b} f(x)\,dx',
    ),
    _EquationTemplate(
      r'\int f(x) \, dx',
      'تكامل غير محدد',
      preview: r'\int f(x)\,dx',
    ),
    _EquationTemplate(
      r'\lim_{x \to \infty} f(x)',
      'نهاية',
      preview: r'\lim_{x\to\infty} f(x)',
    ),
    _EquationTemplate(r'\frac{dy}{dx}', 'مشتقة', preview: r'\frac{dy}{dx}'),
    _EquationTemplate(
      r'\frac{\partial f}{\partial x}',
      'مشتقة جزئية',
      preview: r'\frac{\partial f}{\partial x}',
    ),
    _EquationTemplate(r'\log_{a} x', 'لوغاريتم', preview: r'\log_{a}x'),
    _EquationTemplate(r'\binom{n}{k}', 'توافيق', preview: r'\binom{n}{k}'),
    _EquationTemplate(
      r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
      'مصفوفة 2×2',
      preview: r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
    ),
    _EquationTemplate(r'|\vec{A}|', 'متجه', preview: r'|\vec{A}|'),
    _EquationTemplate(r'\vec{F} = m\vec{a}', 'قانون نيوتن',
        preview: r'\vec{F}=m\vec{a}'),
    _EquationTemplate(r'E = mc^{2}', 'طاقة أينشتاين', preview: r'E=mc^2'),
    _EquationTemplate(r'a^2 + b^2 = c^2', 'فيثاغورس', preview: r'a^2+b^2=c^2'),
    _EquationTemplate(r'e^{i\pi} + 1 = 0', 'أويلر', preview: r'e^{i\pi}+1=0'),
    _EquationTemplate(r'PV = nRT', 'قانون الغاز المثالي', preview: r'PV=nRT'),
  ];

  static final List<_EquationCategory> _equationCategories = [
    _EquationCategory(
      id: 'fractions',
      label: 'كسور',
      icon: Icons.horizontal_split,
      groups: [
        _EquationGroup(
          title: 'كسور شائعة',
          templates: [
            _EquationTemplate(r'\frac{a}{b}', 'كسر بسيط',
                preview: r'\frac{\Box}{\Box}'),
            _EquationTemplate(r'\frac{dy}{dx}', 'مشتقة',
                preview: r'\frac{dy}{dx}'),
            _EquationTemplate(r'\frac{\partial y}{\partial x}', 'مشتقة جزئية',
                preview: r'\frac{\partial y}{\partial x}'),
            _EquationTemplate(r'\frac{\Delta y}{\Delta x}', 'فرق محدود',
                preview: r'\frac{\Delta y}{\Delta x}'),
            _EquationTemplate(r'\frac{x}{y}', 'نسبة', preview: r'\frac{x}{y}'),
            _EquationTemplate(r'\frac{\pi}{2}', 'زاوية',
                preview: r'\frac{\pi}{2}'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'scripts',
      label: 'علوي/سفلي',
      icon: Icons.keyboard_arrow_up,
      groups: [
        _EquationGroup(
          title: 'أحرف منخفضة ومرتفعة',
          templates: [
            _EquationTemplate(r'x^{2}', 'أس عادي', preview: r'x^2'),
            _EquationTemplate(r'x_{1}', 'دليل سفلي', preview: r'x_1'),
            _EquationTemplate(r'x_{1}^{2}', 'سفلي وعلوي', preview: r'x_1^2'),
            _EquationTemplate(r'e^{-i\omega t}', 'أس أسي',
                preview: r'e^{-i\omega t}'),
            _EquationTemplate(r'n_{1}^{\gamma}', 'مركب',
                preview: r'n_1^\gamma'),
            _EquationTemplate(r'x^{y^2}', 'أس متداخل', preview: r'x^{y^2}'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'radicals',
      label: 'جذور',
      icon: Icons.square_foot,
      groups: [
        _EquationGroup(
          title: 'جذور',
          templates: [
            _EquationTemplate(r'\sqrt{x}', 'جذر تربيعي',
                preview: r'\sqrt{\Box}'),
            _EquationTemplate(r'\sqrt[3]{x}', 'جذر تكعيبي',
                preview: r'\sqrt[3]{\Box}'),
            _EquationTemplate(r'\sqrt[n]{x}', 'جذر نوني',
                preview: r'\sqrt[n]{\Box}'),
            _EquationTemplate(r'\sqrt{x^2+y^2}', 'جذر مركب',
                preview: r'\sqrt{x^2+y^2}'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'integrals',
      label: 'تكامل',
      icon: Icons.functions,
      groups: [
        _EquationGroup(
          title: 'تكاملات ونهايات',
          templates: [
            _EquationTemplate(r'\int f(x)\,dx', 'تكامل بسيط',
                preview: r'\int f(x)\,dx'),
            _EquationTemplate(r'\int_{a}^{b} f(x)\,dx', 'تكامل محدد',
                preview: r'\int_{a}^{b} f(x)\,dx'),
            _EquationTemplate(r'\sum_{i=1}^{n} x_i', 'مجموع كبير',
                preview: r'\sum_{i=1}^{n} x_i'),
            _EquationTemplate(r'\prod_{i=1}^{n} x_i', 'حاصل ضرب كبير',
                preview: r'\prod_{i=1}^{n} x_i'),
            _EquationTemplate(r'\lim_{x\to\infty} f(x)', 'نهاية',
                preview: r'\lim_{x\to\infty} f(x)'),
            _EquationTemplate(r'\oint_C f(z)\,dz', 'تكامل حول مسار',
                preview: r'\oint_C f(z)\,dz'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'brackets',
      label: 'أقواس',
      icon: Icons.data_array,
      groups: [
        _EquationGroup(
          title: 'تجميع وأقواس',
          templates: [
            _EquationTemplate(r'\left( \frac{a}{b} \right)', 'قوسان',
                preview: r'\left(\frac{\Box}{\Box}\right)'),
            _EquationTemplate(r'\left[ x+y \right]', 'مربعان',
                preview: r'\left[x+y\right]'),
            _EquationTemplate(r'\left\{ x+y \right\}', 'معقوفان',
                preview: r'\left\{x+y\right\}'),
            _EquationTemplate(r'\left| x \right|', 'قيمة مطلقة',
                preview: r'\left|x\right|'),
            _EquationTemplate(r'\binom{n}{k}', 'توافيق',
                preview: r'\binom{n}{k}'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'matrices',
      label: 'مصفوفات',
      icon: Icons.grid_on,
      groups: [
        _EquationGroup(
          title: 'مصفوفات ومتجهات',
          templates: [
            _EquationTemplate(
                r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}', '2×2',
                preview: r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}'),
            _EquationTemplate(
                r'\begin{pmatrix} a & b & c \\ d & e & f \end{pmatrix}', '2×3',
                preview:
                    r'\begin{pmatrix} a & b & c \\ d & e & f \end{pmatrix}'),
            _EquationTemplate(
                r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}', 'محدد',
                preview: r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}'),
            _EquationTemplate(
                r'\vec{v}=\begin{bmatrix} x \\ y \\ z \end{bmatrix}',
                'متجه عمودي',
                preview: r'\vec{v}=\begin{bmatrix} x \\ y \\ z \end{bmatrix}'),
          ],
        ),
      ],
    ),
    _EquationCategory(
      id: 'science',
      label: 'جاهز',
      icon: Icons.science_outlined,
      groups: [
        _EquationGroup(
          title: 'قوالب جاهزة للعلوم',
          templates: [
            _EquationTemplate(r'\vec{F}=m\vec{a}', 'قانون نيوتن',
                preview: r'\vec{F}=m\vec{a}'),
            _EquationTemplate(r'E=mc^2', 'أينشتاين', preview: r'E=mc^2'),
            _EquationTemplate(
                r'\frac{1}{\lambda}=R\left(\frac{1}{n_1^2}-\frac{1}{n_2^2}\right)',
                'معادلة ريدبرغ',
                preview:
                    r'\frac{1}{\lambda}=R\left(\frac{1}{n_1^2}-\frac{1}{n_2^2}\right)',
                hint: 'مماثلة لمثال وورد'),
            _EquationTemplate(r'a^2+b^2=c^2', 'فيثاغورس',
                preview: r'a^2+b^2=c^2'),
            _EquationTemplate(r'PV=nRT', 'الغاز المثالي', preview: r'PV=nRT'),
            _EquationTemplate(r'e^{i\pi}+1=0', 'أويلر',
                preview: r'e^{i\pi}+1=0'),
          ],
        ),
      ],
    ),
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
  final String preview;
  final String? hint;

  const _EquationTemplate(
    this.latex,
    this.label, {
    String? preview,
    this.hint,
  }) : preview = preview ?? latex;
}

class _EquationCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<_EquationGroup> groups;

  const _EquationCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.groups,
  });
}

class _EquationGroup {
  final String title;
  final List<_EquationTemplate> templates;

  const _EquationGroup({
    required this.title,
    required this.templates,
  });
}

/// A safe, WebView-free LaTeX preview widget using flutter_math_fork.
/// Falls back to a styled plain-text display if the formula can't be parsed.
class _SafeMathPreview extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double mathSize;

  const _SafeMathPreview({
    required this.latex,
    required this.textColor,
    this.mathSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (latex.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        latex,
        textStyle: TextStyle(
          fontSize: mathSize,
          color: textColor,
        ),
        onErrorFallback: (err) => _LatexFallbackText(
          latex: latex,
          textColor: textColor,
          fontSize: mathSize * 0.75,
        ),
      ),
    );
  }
}

class _LatexFallbackText extends StatelessWidget {
  final String latex;
  final Color textColor;
  final double fontSize;

  const _LatexFallbackText({
    required this.latex,
    required this.textColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      latex,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize.clamp(9.0, 14.0),
        color: textColor.withOpacity(0.7),
        height: 1.3,
      ),
    );
  }
}
