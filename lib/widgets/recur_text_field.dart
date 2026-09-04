import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A labelled text field: label above (colour reflects state), the input
/// itself, and optional helper/error text below.
class RecurTextField extends StatefulWidget {
  const RecurTextField({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.errorText,
    this.helperText,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.focusNode,
  });

  /// Shown above the field.
  final String label;

  final TextEditingController controller;

  /// Hint text shown inside the field when empty.
  final String? placeholder;

  /// When non-null, the field renders in its error state and shows this
  /// text below in place of [helperText].
  final String? errorText;

  /// Shown below the field, muted, when there is no [errorText].
  final String? helperText;

  final int maxLines;

  final int? maxLength;

  final TextInputType? keyboardType;

  final FocusNode? focusNode;

  @override
  State<RecurTextField> createState() => _RecurTextFieldState();
}

class _RecurTextFieldState extends State<RecurTextField> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  bool get _hasError =>
      widget.errorText != null && widget.errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final disabled = !_focusNode.canRequestFocus;

    final Color labelColor;
    if (_hasError) {
      labelColor = RecurColors.error;
    } else if (_focused) {
      labelColor = RecurColors.primary;
    } else {
      labelColor = RecurColors.muted;
    }

    final Color borderColor;
    final double borderWidth;
    if (_hasError) {
      borderColor = RecurColors.error;
      borderWidth = 2;
    } else if (_focused) {
      borderColor = RecurColors.primary;
      borderWidth = 2;
    } else {
      borderColor = RecurColors.divider;
      borderWidth = 1;
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RecurRadii.field),
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: RecurText.label.copyWith(color: labelColor)),
        const SizedBox(height: RecurSpacing.xs),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: !disabled,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          style: RecurText.body.copyWith(color: RecurColors.text),
          textAlignVertical: widget.maxLines > 1 ? TextAlignVertical.top : null,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: RecurText.body.copyWith(color: RecurColors.muted),
            filled: true,
            fillColor: disabled ? RecurColors.blocked : RecurColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            errorBorder: border,
            focusedErrorBorder: border,
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RecurRadii.field),
              borderSide: const BorderSide(
                color: RecurColors.divider,
                width: 1,
              ),
            ),
            counterStyle: RecurText.caption.copyWith(color: RecurColors.muted),
            counterText: widget.maxLength == null ? '' : null,
            isCollapsed: false,
          ),
        ),
        if (!disabled &&
            (_hasError || (widget.helperText?.isNotEmpty ?? false))) ...[
          const SizedBox(height: RecurSpacing.xs),
          Text(
            _hasError ? widget.errorText! : widget.helperText!,
            style: RecurText.caption.copyWith(
              color: _hasError ? RecurColors.error : RecurColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}
