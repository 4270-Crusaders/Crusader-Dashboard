import 'package:flutter/material.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';

/// Opens a searchable list of announced NT topics. Returns the selected topic
/// name, or null if cancelled.
Future<String?> showNTTopicPicker({
  required BuildContext context,
  required NTConnection ntConnection,
}) => showDialog<String>(
      context: context,
      builder: (ctx) => _NTTopicPickerDialog(ntConnection: ntConnection),
    );

class _NTTopicPickerDialog extends StatefulWidget {
  final NTConnection ntConnection;

  const _NTTopicPickerDialog({required this.ntConnection});

  @override
  State<_NTTopicPickerDialog> createState() => _NTTopicPickerDialogState();
}

class _NTTopicPickerDialogState extends State<_NTTopicPickerDialog> {
  String _query = '';
  late final TextEditingController _searchCtrl = TextEditingController();

  List<NT4Topic> get _allTopics {
    final topics = widget.ntConnection
        .announcedTopics()
        .values
        .where((t) => !t.name.startsWith('/.'))
        .toList();
    topics.sort((a, b) => a.name.compareTo(b.name));
    return topics;
  }

  List<NT4Topic> get _filtered {
    if (_query.isEmpty) return _allTopics;
    final q = _query.toLowerCase();
    return _allTopics.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AlertDialog(
      title: const Text('Select NT Topic'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search topics...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.ntConnection.isNT4Connected
                            ? 'No topics match'
                            : 'Not connected — topics unavailable',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final topic = filtered[i];
                        final parts = topic.name.split('/');
                        final leaf = parts.last;
                        final parent =
                            parts.length > 2 ? parts.sublist(1, parts.length - 1).join('/') : '';

                        return ListTile(
                          dense: true,
                          title: Text(
                            leaf,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: parent.isNotEmpty ? Text(parent) : null,
                          trailing: Text(
                            topic.type.name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => Navigator.of(ctx).pop(topic.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
