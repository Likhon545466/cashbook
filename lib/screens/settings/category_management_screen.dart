import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../providers/category_provider.dart';
import '../../utils/category_icon.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  String _type = 'expense';

  Future<void> _addCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'Category name'),
            onSubmitted: (value) {
              Navigator.pop(dialogContext, value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || name == null || name.trim().isEmpty) return;

    final added = await context.read<CategoryProvider>().addCategory(
      name: name,
      type: _type,
    );

    if (!mounted) return;

    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category already exists or is invalid.')),
      );
    }
  }

  Future<void> _deleteCategory(CashCategory category) async {
    if (category.isDefault) return;

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete category?'),
            content: Text(
              'Delete "${category.name}" from your category list? '
              'Existing transactions will keep the saved category name.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    await context.read<CategoryProvider>().deleteCategory(category);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${category.name} removed.')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final items = provider.byType(_type);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'income', label: Text('Income')),
              ButtonSegment(value: 'expense', label: Text('Expense')),
            ],
            selected: {_type},
            onSelectionChanged: (selection) {
              setState(() => _type = selection.first);
            },
          ),
          const SizedBox(height: 18),
          ...items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    CategoryIcon.forName(
                      item.name,
                      isIncome: _type == 'income',
                    ),
                    size: 20,
                  ),
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  item.isDefault ? 'Default category' : 'Custom category',
                ),
                trailing: item.isDefault
                    ? const Icon(Icons.lock_outline_rounded, size: 19)
                    : IconButton(
                        tooltip: 'Delete category',
                        onPressed: () => _deleteCategory(item),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
