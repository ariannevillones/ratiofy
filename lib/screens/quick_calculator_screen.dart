import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/ui_labels.dart';
import '../widgets/add_recipe_sheet.dart';

/// Which of the four a:b = c:d slots is currently being solved for — the
/// other three must be filled in by the user.
enum _Slot { a, b, c, d }

/// Standalone "solve a:b = c:d" calculator — independent of any saved
/// recipe. Fill in any three of the four values and this solves the
/// fourth by cross-multiplication (a*d = b*c).
class QuickCalculatorScreen extends StatefulWidget {
  const QuickCalculatorScreen({super.key});

  @override
  State<QuickCalculatorScreen> createState() => _QuickCalculatorScreenState();
}

class _QuickCalculatorScreenState extends State<QuickCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    for (final slot in _Slot.values) slot: TextEditingController(),
  };
  _Slot _solveFor = _Slot.d;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _labelFor(_Slot slot) => switch (slot) {
        _Slot.a => 'a',
        _Slot.b => 'b',
        _Slot.c => 'c',
        _Slot.d => 'd',
      };

  void _clear() {
    setState(() {
      for (final controller in _controllers.values) {
        controller.clear();
      }
      _error = null;
    });
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final known = {
      for (final slot in _Slot.values)
        if (slot != _solveFor) slot: double.parse(_controllers[slot]!.text),
    };

    double result;
    switch (_solveFor) {
      case _Slot.a:
        if (known[_Slot.d] == 0) {
          setState(() => _error = QuickCalculatorLabels.divisionByZero);
          return;
        }
        result = known[_Slot.b]! * known[_Slot.c]! / known[_Slot.d]!;
        break;
      case _Slot.b:
        if (known[_Slot.c] == 0) {
          setState(() => _error = QuickCalculatorLabels.divisionByZero);
          return;
        }
        result = known[_Slot.a]! * known[_Slot.d]! / known[_Slot.c]!;
        break;
      case _Slot.c:
        if (known[_Slot.b] == 0) {
          setState(() => _error = QuickCalculatorLabels.divisionByZero);
          return;
        }
        result = known[_Slot.a]! * known[_Slot.d]! / known[_Slot.b]!;
        break;
      case _Slot.d:
        if (known[_Slot.a] == 0) {
          setState(() => _error = QuickCalculatorLabels.divisionByZero);
          return;
        }
        result = known[_Slot.b]! * known[_Slot.c]! / known[_Slot.a]!;
        break;
    }

    setState(() {
      _error = null;
      _controllers[_solveFor]!.text = _formatNumber(result);
    });
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    // Trim trailing zeros from a fixed-precision string.
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _share() {
    final text = QuickCalculatorLabels.shareText(
      _controllers[_Slot.a]!.text,
      _controllers[_Slot.b]!.text,
      _controllers[_Slot.c]!.text,
      _controllers[_Slot.d]!.text,
    );
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    Share.share(text, sharePositionOrigin: origin);
  }

  Widget _buildField(_Slot slot) {
    final isSolveFor = slot == _solveFor;
    return TextFormField(
      controller: _controllers[slot],
      enabled: !isSolveFor,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: _labelFor(slot),
        hintText: isSolveFor ? '?' : null,
      ),
      validator: isSolveFor
          ? null
          : (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return QuickCalculatorLabels.requiredValidation;
              }
              if (double.tryParse(trimmed) == null) {
                return QuickCalculatorLabels.invalidNumberValidation;
              }
              return null;
            },
      onChanged: (_) => setState(() => _error = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResult = _controllers[_solveFor]!.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text(QuickCalculatorLabels.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                QuickCalculatorLabels.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  dense: true,
                  leading: Icon(Icons.info_outline,
                      size: 20, color: theme.colorScheme.primary),
                  title: Text(
                    QuickCalculatorLabels.howItWorksTitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        QuickCalculatorLabels.howItWorksBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<_Slot>(
                initialValue: _solveFor,
                decoration: const InputDecoration(
                    labelText: QuickCalculatorLabels.solveForLabel),
                items: [
                  for (final slot in _Slot.values)
                    DropdownMenuItem(
                        value: slot, child: Text(_labelFor(slot))),
                ],
                onChanged: (slot) {
                  if (slot == null) return;
                  setState(() {
                    _solveFor = slot;
                    _controllers[slot]!.clear();
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildField(_Slot.a)),
                  Padding(
                    padding: const EdgeInsets.only(top: 14, left: 8, right: 8),
                    child: Text(
                      ':',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(child: _buildField(_Slot.b)),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.center,
                child: Text('=', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildField(_Slot.c)),
                  Padding(
                    padding: const EdgeInsets.only(top: 14, left: 8, right: 8),
                    child: Text(
                      ':',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(child: _buildField(_Slot.d)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate_outlined),
                      label:
                          const Text(QuickCalculatorLabels.calculateButton),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _clear,
                    child: const Text(QuickCalculatorLabels.clearButton),
                  ),
                ],
              ),
              if (hasResult && _error == null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        QuickCalculatorLabels.resultLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_labelFor(_solveFor)} = ${_controllers[_solveFor]!.text}',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text(
                              QuickCalculatorLabels.shareResult),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        QuickCalculatorLabels.moreValuesTitle,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        QuickCalculatorLabels.moreValuesBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => showAddRecipeOptions(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                              QuickCalculatorLabels.createRecipeButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
