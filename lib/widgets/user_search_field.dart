import 'dart:async';

import 'package:flutter/material.dart';

typedef UserSearch = Future<List<Map<String, dynamic>>> Function(String query);

class UserSearchField extends StatefulWidget {
  const UserSearchField({
    super.key,
    required this.label,
    required this.search,
    required this.excludedIds,
    required this.onSelected,
    this.onEdited,
    this.validator,
    this.clearAfterSelection = false,
    this.enabled = true,
  });
  final String label;
  final UserSearch search;
  final Set<String> excludedIds;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final VoidCallback? onEdited;
  final FormFieldValidator<String>? validator;
  final bool clearAfterSelection, enabled;
  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  final controller = TextEditingController();
  Timer? debounce;
  int request = 0;
  bool loading = false, showResults = false;
  String? error;
  List<Map<String, dynamic>> results = [];

  void changed(String value) {
    widget.onEdited?.call();
    debounce?.cancel();
    final token = ++request;
    final query = value.trim();
    setState(() {
      results = [];
      error = null;
      showResults = query.isNotEmpty;
      loading = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    debounce = Timer(
      const Duration(milliseconds: 300),
      () => search(query, token),
    );
  }

  Future<void> search(String query, int token) async {
    try {
      final matches = await widget.search(query);
      if (!mounted || request != token) return;
      setState(() {
        results = matches;
        loading = false;
      });
    } catch (_) {
      if (!mounted || request != token) return;
      setState(() {
        error = 'Could not search users. Try typing again.';
        loading = false;
      });
    }
  }

  void select(Map<String, dynamic> user) {
    if (widget.excludedIds.contains(user['id'])) return;
    debounce?.cancel();
    request++;
    setState(() {
      controller.text = widget.clearAfterSelection
          ? ''
          : user['username'] as String;
      showResults = false;
      loading = false;
      results = [];
      error = null;
    });
    widget.onSelected(user);
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = results
        .where((u) => !widget.excludedIds.contains(u['id']))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          enabled: widget.enabled,
          autocorrect: false,
          validator: widget.validator,
          onChanged: changed,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Search username',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: widget.enabled
                        ? () {
                            controller.clear();
                            changed('');
                          }
                        : null,
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        if (showResults)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: loading
                ? const LinearProgressIndicator()
                : error != null
                ? Text(error!)
                : visible.isEmpty
                ? const Text('No matching users.')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: visible.map((u) {
                        final duplicate =
                            visible
                                .where((v) => v['username'] == u['username'])
                                .length >
                            1;
                        final id = u['id'] as String;
                        return ListTile(
                          key: ValueKey('user-result-$id'),
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(
                            u['username'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: duplicate
                              ? Text(
                                  'Account ${id.substring(0, id.length < 8 ? id.length : 8)}',
                                )
                              : null,
                          onTap: widget.enabled ? () => select(u) : null,
                        );
                      }).toList(),
                    ),
                  ),
          ),
      ],
    );
  }
}
