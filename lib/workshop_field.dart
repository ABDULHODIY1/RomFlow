import 'adaptive_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Number pads on some phones have no return key. Keep completion reachable.
class WorkshopKeyboardTools extends StatelessWidget {
  final Widget child;
  const WorkshopKeyboardTools({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;
    if (bottom <= 0) return child;
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              viewInsets: media.viewInsets.copyWith(bottom: bottom + 48),
            ),
            child: child,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          height: 48,
          child: TextFieldTapRegion(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.nextFocus(),
                    icon: const Icon(Icons.keyboard_tab, size: 18),
                    label: const Text('Keyingisi'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
                    label: const Text('Tayyor'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Accept decimal commas and pasted spaces without changing the number's value.
class WorkshopNumberFormatter extends TextInputFormatter {
  final bool decimal;
  WorkshopNumberFormatter({this.decimal = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    String clean(String s) =>
        s.replaceAll(RegExp(r'[\s\u00a0\u202f]'), '').replaceAll(',', '.');
    final text = clean(newValue.text);
    if (!(decimal ? RegExp(r'^\d*(\.\d*)?$') : RegExp(r'^\d*$')).hasMatch(
      text,
    )) {
      return oldValue;
    }
    int offset(int n) => n < 0
        ? text.length
        : clean(
            newValue.text.substring(0, n.clamp(0, newValue.text.length)),
          ).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
    );
  }
}

/// Shared workshop input: readable labels, predictable focus, inline validation.
class WorkshopField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool number, decimal, obscure, selectOnFocus;
  final TextInputType? keyboardType;
  final TextInputAction action;
  final String? helperText, suffixText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged, onSubmitted;
  const WorkshopField({
    super.key,
    required this.controller,
    required this.label,
    this.number = false,
    this.decimal = true,
    this.obscure = false,
    this.selectOnFocus = true,
    this.keyboardType,
    this.action = TextInputAction.next,
    this.helperText,
    this.suffixText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  });
  @override
  State<WorkshopField> createState() => _WorkshopFieldState();
}

class _WorkshopFieldState extends State<WorkshopField> {
  final focus = FocusNode();
  bool firstTap = true;
  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) firstTap = true;
    });
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassControl(
        child: TextFormField(
          controller: widget.controller,
          focusNode: focus,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType ??
              (widget.number
                  ? TextInputType.numberWithOptions(decimal: widget.decimal)
                  : TextInputType.text),
          textInputAction: widget.action,
          textCapitalization: widget.number
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          inputFormatters: widget.number
              ? [WorkshopNumberFormatter(decimal: widget.decimal)]
              : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          scrollPadding: const EdgeInsets.all(32),
          onTapOutside: (_) => focus.unfocus(),
          onTap: () {
            if (firstTap && widget.number && widget.selectOnFocus) {
              widget.controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: widget.controller.text.length,
              );
            }
            firstTap = false;
          },
          onChanged: widget.onChanged,
          onFieldSubmitted: (value) {
            if (widget.action == TextInputAction.done) focus.unfocus();
            widget.onSubmitted?.call(value);
          },
          validator: (value) {
            final custom = widget.validator?.call(value);
            if (custom != null) return custom;
            if (widget.number) {
              final n = num.tryParse(value ?? '');
              if (n == null || !n.isFinite || n < 0) {
                return '0 yoki musbat son kiriting';
              }
            }
            return null;
          },
          decoration: InputDecoration(
            label: Text(widget.label, maxLines: 2),
            helperText: widget.helperText,
            helperMaxLines: 3,
            errorMaxLines: 3,
            suffixText: widget.suffixText,
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox(width: 48, height: 48)
                  : IconButton(
                      tooltip: 'Tozalash',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        widget.controller.clear();
                        focus.requestFocus();
                        widget.onChanged?.call('');
                      },
                    ),
            ),
          ),
        ),
      );
}
