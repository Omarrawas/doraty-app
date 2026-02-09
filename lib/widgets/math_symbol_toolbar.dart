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
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              _MathTemplate('→', 'تفاعل تام', '→'),
              _MathTemplate('⇌', 'تفاعل عكسي (اتزان)', '⇌'),
              _MathTemplate('↑', 'تصاعد غاز', '↑'),
              _MathTemplate('↓', 'ترسب (راسب)', '↓'),
              _MathTemplate(r'\( \xrightarrow{\Delta} \)', 'تسخين', '→ (Δ)'),
              _MathTemplate(r'\( \xrightarrow{pt} \)', 'عامل حفاز', '→ (pt)'),
              _MathTemplate(r'\( \xrightarrow{H_2O} \)', 'تميؤ', '→ (H₂O)'),
              _MathTemplate(r'\( \xrightleftharpoons[k_2]{k_1} \)', 'اتزان بأسماء ثوابت', '⇌ (k)'),
              _MathTemplate('(s)', 'حالة صلبة', '(s)'),
              _MathTemplate('(l)', 'حالة سائلة', '(l)'),
              _MathTemplate('(g)', 'حالة غازية', '(g)'),
              _MathTemplate('(aq)', 'محلول مائي', '(aq)'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<String>(
        onSelected: onSymbolSelected,
        offset: const Offset(0, -350),
        tooltip: label,
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                iconLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        itemBuilder: (context) => templates.map((t) {
          return PopupMenuItem<String>(
            value: t.value,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      t.preview,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.label,
                    style: const TextStyle(fontSize: 13),
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
}

class _MathTemplate {
  final String value;
  final String label;
  final String preview;

  _MathTemplate(this.value, this.label, this.preview);
}
