import 'package:flutter/material.dart';

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
    final background = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F3F3);
    final border = isDark ? Colors.white12 : const Color(0xFFD0D0D0);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: background,
        gradient: LinearGradient(
          colors: [
            background.withOpacity(0.98),
            background.withOpacity(0.9),
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
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          _buildCategoryMenu(
            context,
            'الرموز',
            'αΩ',
            [
              _MathTemplate('α', 'ألفا', 'α'),
              _MathTemplate('β', 'بيتا', 'β'),
              _MathTemplate('γ', 'غاما', 'γ'),
              _MathTemplate('δ', 'دلتا', 'δ'),
              _MathTemplate('ε', 'إبسيلون', 'ε'),
              _MathTemplate('ζ', 'زيتا', 'ζ'),
              _MathTemplate('η', 'إيتا', 'η'),
              _MathTemplate('θ', 'ثيتا', 'θ'),
              _MathTemplate('ι', 'أيوتا', 'ι'),
              _MathTemplate('κ', 'كابة', 'κ'),
              _MathTemplate('λ', 'لامدا', 'λ'),
              _MathTemplate('μ', 'ميو', 'μ'),
              _MathTemplate('ν', 'نيو', 'ν'),
              _MathTemplate('ξ', 'كسي', 'ξ'),
              _MathTemplate('π', 'باي', 'π'),
              _MathTemplate('ρ', 'رو', 'ρ'),
              _MathTemplate('σ', 'سيغما', 'σ'),
              _MathTemplate('τ', 'تاو', 'τ'),
              _MathTemplate('φ', 'فاي', 'φ'),
              _MathTemplate('χ', 'كاي', 'χ'),
              _MathTemplate('ψ', 'بساي', 'ψ'),
              _MathTemplate('ω', 'أوميغا', 'ω'),
              _MathTemplate('Δ', 'دلتا كابيتال', 'Δ'),
              _MathTemplate('Ω', 'أوميغا كابيتال', 'Ω'),
              _MathTemplate('Σ', 'سيغما كابيتال', 'Σ'),
              _MathTemplate('Phi', 'فاي كابيتال', 'Φ'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'كيمياء',
            '⇌',
            [
              _MathTemplate('?', '????? ???', '?'),
              _MathTemplate('?', '????? ????', '?'),
              _MathTemplate('?', '????? ???? (?????)', '?'),
              _MathTemplate('?', '???????', '?'),
              _MathTemplate('?', '????? ???', '?'),
              _MathTemplate('?', '???? (????)', '?'),
              _MathTemplate('?', '???? ?????', '?'),
              _MathTemplate('H?O', '???', 'H?O'),
              _MathTemplate('CO?', '???? ????? ???????', 'CO?'),
              _MathTemplate('SO???', '???????', 'SO???'),
              _MathTemplate('NH??', '???????', 'NH??'),
              _MathTemplate('Na?', '??????', 'Na?'),
              _MathTemplate('Cl?', '??????', 'Cl?'),
              _MathTemplate('Ca??', '???????', 'Ca??'),
              _MathTemplate('Al??', '????????', 'Al??'),
              _MathTemplate('O??', '?????', 'O??'),
              _MathTemplate('S??', '???????', 'S??'),
              _MathTemplate('NO??', '?????', 'NO??'),
              _MathTemplate('CO???', '???????', 'CO???'),
              _MathTemplate('PO???', '??????', 'PO???'),
              _MathTemplate('?', '??? ???? 0', '?'),
              _MathTemplate('?', '??? ???? 1', '?'),
              _MathTemplate('?', '??? ???? 2', '?'),
              _MathTemplate('?', '??? ???? 3', '?'),
              _MathTemplate('?', '??? ???? 4', '?'),
              _MathTemplate('?', '??? ???? 5', '?'),
              _MathTemplate('?', '??? ???? 6', '?'),
              _MathTemplate('?', '??? ???? 7', '?'),
              _MathTemplate('?', '??? ???? 8', '?'),
              _MathTemplate('?', '??? ???? 9', '?'),
              _MathTemplate('?', '???? ?????', '?'),
              _MathTemplate('?', '???? ?????', '?'),
              _MathTemplate('??', '???? 2+', '??'),
              _MathTemplate('??', '???? 2-', '??'),
              _MathTemplate('??', '???? 3+', '??'),
              _MathTemplate('??', '???? 3-', '??'),
              _MathTemplate(r'\( \xrightarrow{\Delta} \)', '?????', '? (?)'),
              _MathTemplate(r'\( \xrightarrow{pt} \)', '???? ????', '? (pt)'),
              _MathTemplate(r'\( \xrightarrow{H_2O} \)', '????', '? (H?O)'),
              _MathTemplate(r'\( \xrightleftharpoons[k_2]{k_1} \)', '????? ?????? ?????', '? (k)'),
              _MathTemplate('(s)', '???? ????', '(s)'),
              _MathTemplate('(l)', '???? ?????', '(l)'),
              _MathTemplate('(g)', '???? ?????', '(g)'),
              _MathTemplate('(aq)', '????? ????', '(aq)'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'كسر',
            'x/y',
            [
              _MathTemplate(r'\( \frac{}{} \)', 'كسر رأسي', '󰡬'),
              _MathTemplate(r'\( \tfrac{}{} \)', 'كسر صغير', '½'),
              _MathTemplate('/', 'كسر مائل', '/'),
              _MathTemplate(r'\( ^{}/_{} \)', 'كسر خطي', 'x/y'),
              _MathTemplate(r'\( \cfrac{}{} \)', 'كسر مستمر', '󰡬󰡬'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'برنامج نصي',
            'eˣ',
            [
              _MathTemplate(r'^{}', 'أس علوي', 'xʸ'),
              _MathTemplate(r'_{}', 'دليل سفلي', 'xᵧ'),
              _MathTemplate(r'^{}_{}', 'أس ودليل علوي وسفلي', 'xᵧᶻ'),
              _MathTemplate(r'{}^{}_{}\Box', 'أس ودليل من اليسار', 'ʸᶻx'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'جذري',
            'ⁿ√x',
            [
              _MathTemplate(r'\( \sqrt{} \)', 'جذر تربيعي', '√'),
              _MathTemplate(r'\( \sqrt[2]{} \)', 'جذر تربيعي برقم', '²√'),
              _MathTemplate(r'\( \sqrt[3]{} \)', 'جذر تكعيبي', '∛'),
              _MathTemplate(r'\( \sqrt[]{} \)', 'جذر نوني', 'ⁿ√'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'تكامل',
            '∫',
            [
              _MathTemplate(r'\( \int \)', 'تكامل بسيط', '∫'),
              _MathTemplate(r'\( \int_{}^{} \)', 'تكامل بحدود', '∫ₐᵇ'),
              _MathTemplate(r'\( \iint \)', 'تكامل ثنائي', '∬'),
              _MathTemplate(r'\( \oint \)', 'تكامل مساري', '∮'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'عامل تشغيل كبير',
            '∑',
            [
              _MathTemplate('∑', 'مجموع', '∑'),
              _MathTemplate(r'\( \sum_{}^{} \)', 'مجموع بحدود', '∑ᵢ₌₁ⁿ'),
              _MathTemplate(r'\( \sum_{} \)', 'مجموع بحد سفلي', '∑ᵢ'),
              _MathTemplate('∏', 'حاصل طلب', '∏'),
              _MathTemplate(r'\( \prod_{}^{} \)', 'حاصل طلب بحدود', '∏ᵢ₌₁ⁿ'),
              _MathTemplate('⋂', 'تقاطع كبير', '⋂'),
              _MathTemplate('⋃', 'اتحاد كبير', '⋃'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'قوس',
            '{()} ',
            [
              _MathTemplate('(', 'أقواس عادية', '(x)'),
              _MathTemplate('[', 'أقواس مربعة', '[x]'),
              _MathTemplate('{', 'أقواس مجموعة', '{x}'),
              _MathTemplate('|', 'قدر مطلق', '|x|'),
              _MathTemplate(r'\( \left( \right) \)', 'أقواس متمددة', '(...)'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'دالة',
            'sinθ',
            [
              _MathTemplate('sin', 'جا', 'sin'),
              _MathTemplate('cos', 'جتا', 'cos'),
              _MathTemplate('tan', 'ظا', 'tan'),
              _MathTemplate('cot', 'ظتا', 'cot'),
              _MathTemplate('sec', 'قا', 'sec'),
              _MathTemplate('csc', 'قتا', 'csc'),
              _MathTemplate('sin⁻¹', 'جا عكسية', 'sin⁻¹'),
              _MathTemplate('cos⁻¹', 'جتا عكسية', 'cos⁻¹'),
              _MathTemplate('tan⁻¹', 'ظا عكسية', 'tan⁻¹'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'التمييز',
            'ä',
            [
              _MathTemplate(r'\( \dot{} \)', 'نقطة علوية', 'ẋ'),
              _MathTemplate(r'\( \ddot{} \)', 'نقطتين علوية', 'ẍ'),
              _MathTemplate('â', 'قبعة', 'â'),
              _MathTemplate('ā', 'خط علوي صغير', 'ā'),
              _MathTemplate('v⃗', 'متجه', 'v⃗'),
              _MathTemplate('x→', 'سهم لليمين علوي', 'x→ '),
            ],
          ),
          _buildCategoryMenu(
            context,
            'حد وسجل',
            'lim',
            [
              _MathTemplate('lim', 'نهاية بلا حدود', 'lim'),
              _MathTemplate(r'\( \lim_{x \to \infty} \)', 'نهاية بحدود', 'limₓ→∞'),
              _MathTemplate('log', 'لوغاريتم', 'log'),
              _MathTemplate(r'\( \log_{10} \)', 'لوغاريتم بأساس', 'log₁₀'),
              _MathTemplate('ln', 'لوغاريتم طبيعي', 'ln'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'أسهم',
            '→',
            [
              _MathTemplate('→', 'سهم لليمين', '→'),
              _MathTemplate('←', 'سهم لليسار', '←'),
              _MathTemplate('↔', 'سهم مزدوج', '↔'),
              _MathTemplate('⇒', 'سهم مزدوج لليمين', '⇒'),
              _MathTemplate('⇐', 'سهم مزدوج لليسار', '⇐'),
              _MathTemplate('⇔', 'سهم مزدوج تبادلي', '⇔'),
            ],
          ),
          _buildCategoryMenu(
            context,
            'مصفوفة',
            '[::]',
            [
              _MathTemplate(r'\( \begin{matrix}  &  \\  &  \end{matrix} \)', '2x2 مصفوفة', '[::]'),
              _MathTemplate(r'\( \begin{matrix}  &  \end{matrix} \)', '1x2 مصفوفة', '[..]'),
              _MathTemplate(r'\( \begin{matrix}  \\  \end{matrix} \)', '2x1 مصفوفة', '[:]'),
              _MathTemplate('...', 'نقاط أفقية', '...'),
              _MathTemplate('⋮', 'نقاط رأسية', '⋮'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryMenu(
    BuildContext context,
    String label,
    String iconLabel,
    List<_MathTemplate> templates,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final border = isDark ? Colors.white12 : const Color(0xFFD0D0D0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1B1B1B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF5C5C5C);
    final accent = isDark ? const Color(0xFF8AB4F8) : const Color(0xFF0F6CBD);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: PopupMenuButton<String>(
        onSelected: onSymbolSelected,
        offset: const Offset(0, -8),
        elevation: 10,
        color: surface,
        constraints: const BoxConstraints(maxHeight: 380, minWidth: 260),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        tooltip: label,
        child: Container(
          width: 84,
          decoration: BoxDecoration(
            color: surface.withOpacity(isDark ? 0.9 : 1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                iconLabel,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Segoe UI',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 9,
                  fontFamily: 'Segoe UI',
                ),
              ),
            ],
          ),
        ),
        itemBuilder: (context) => templates.map((t) {
          return PopupMenuItem<String>(
            value: t.value,
            height: 44,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withOpacity(0.25)),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      t.preview,
                      style: TextStyle(
                        fontSize: 14,
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Segoe UI',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: textPrimary,
                      fontFamily: 'Segoe UI',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Icon(
                  Icons.chevron_left,
                  size: 18,
                  color: textSecondary.withOpacity(0.7),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MathTemplate {
  final String value;
  final String label;
  final String preview;

  _MathTemplate(this.value, this.label, this.preview);
}
