import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/staff_portal/domain/entities/table_draft.dart';
import 'features/staff_portal/presentation/widgets/table_allocation_modal.dart';

void main() => runApp(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Wrap(
                spacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final r = await showTableAllocationDialog(
                        context,
                        title: 'Configure Slot Tables',
                        initialTables: const [
                          TableDraft(tableNo: 1, seats: 4),
                          TableDraft(tableNo: 2, seats: 6),
                        ],
                      );
                      debugPrint('editable: ${r?.map((t) => t.toJson())}');
                    },
                    child: const Text('Editable'),
                  ),
                  ElevatedButton(
                    onPressed: () => showTableAllocationDialog(
                      context,
                      title: 'Layout defined',
                      readOnly: true,
                      initialTables: const [TableDraft(tableNo: 1, seats: 4)],
                    ),
                    child: const Text('Read-only'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );