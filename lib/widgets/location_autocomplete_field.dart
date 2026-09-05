import 'dart:async';

import 'package:flutter/material.dart';

import '../places/places_gateway.dart';
import '../theme/tokens.dart';
import 'recur_text_field.dart';

/// The longest a location can be, matching `EventType`'s own limit.
const int _maxLocationLength = 80;

/// A [RecurTextField] for "Location" that suggests addresses as the user
/// types, via [PlacesGateway]. Looks and behaves exactly like a plain text
/// field until a suggestion list appears below it; picking one fills the
/// field and dismisses the list. Typing something and never picking a
/// suggestion works too - suggestions are a convenience, not a requirement.
class LocationAutocompleteField extends StatefulWidget {
  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.places,
  });

  final TextEditingController controller;
  final PlacesGateway places;

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  int _requestId = 0;
  List<PlaceSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _suggestions.isNotEmpty) {
      setState(() => _suggestions = []);
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final query = widget.controller.text.trim();
    if (query.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    final results = await widget.places.search(query);
    if (!mounted || requestId != _requestId) return;
    setState(() => _suggestions = results);
  }

  void _select(PlaceSuggestion suggestion) {
    final description = suggestion.description.length > _maxLocationLength
        ? suggestion.description.substring(0, _maxLocationLength)
        : suggestion.description;
    widget.controller
      ..text = description
      ..selection = TextSelection.collapsed(offset: description.length);
    setState(() => _suggestions = []);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RecurTextField(
          label: 'Location',
          controller: widget.controller,
          focusNode: _focusNode,
          maxLength: _maxLocationLength,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: RecurSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RecurRadii.field),
              border: Border.all(color: RecurColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: RecurColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final suggestion in _suggestions)
                    ListTile(
                      dense: true,
                      title: Text(
                        suggestion.description,
                        style: RecurText.body.copyWith(color: RecurColors.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _select(suggestion),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
