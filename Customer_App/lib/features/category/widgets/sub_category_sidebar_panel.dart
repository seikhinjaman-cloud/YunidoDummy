import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/widgets/sub_category_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class SubCategorySidebarPanel extends StatefulWidget {
  final PaginationScrollController pager;
  final String? selectedCategoryId;
  // Id of the category currently previewed as a right-side grid (only ever
  // the very first auto-selected category). That one item legitimately
  // shows its own content on the right, so it's the one has_child exception
  // allowed to render as selected.
  final String? autoChildCategoryId;
  final ValueChanged<Category> onSelectCategory;
  final ValueChanged<Category> onAutoSelectCategory;

  const SubCategorySidebarPanel({
    super.key,
    required this.pager,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onAutoSelectCategory,
    this.autoChildCategoryId,
  });

  @override
  State<SubCategorySidebarPanel> createState() =>
      _SubCategorySidebarPanelState();
}

class _SubCategorySidebarPanelState extends State<SubCategorySidebarPanel> {
  // Yunido: one key per item so the sidebar can slide the selected sub-category
  // into view (auto-advance while scrolling products, or after a tap).
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void didUpdateWidget(covariant SubCategorySidebarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId &&
        widget.selectedCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  void _revealSelected() {
    if (!mounted) return;
    final id = widget.selectedCategoryId;
    if (id == null) return;
    final ctx = _itemKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    // Item not built yet (far down a long list): jump near it first, then
    // centre it once it exists.
    final state = context.read<SubCategoryCubit>().state;
    final controller = widget.pager.controller;
    if (state is PaginationLoaded<Category> && controller.hasClients) {
      final index = state.data.indexWhere((c) => c.id == id);
      if (index >= 0) {
        final target = (index * 104.0).clamp(
          0.0,
          controller.position.maxScrollExtent,
        );
        controller
            .animateTo(
              target,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
            .then((_) {
              if (!mounted) return;
              final c = _itemKeys[id]?.currentContext;
              if (c != null) {
                Scrollable.ensureVisible(
                  c,
                  alignment: 0.35,
                  duration: const Duration(milliseconds: 200),
                );
              }
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pager = widget.pager;
    final selectedCategoryId = widget.selectedCategoryId;
    final autoChildCategoryId = widget.autoChildCategoryId;
    final onSelectCategory = widget.onSelectCategory;
    final onAutoSelectCategory = widget.onAutoSelectCategory;
    final sidebarBg = context.cs.surfaceContainerLow;

    return SizedBox(
      width: 84,
      child: BlocConsumer<SubCategoryCubit, PaginationState<Category>>(
        listener: (context, state) {
          if (state is PaginationLoaded<Category>) {
            // Fetch every icon up front so the first tap on any category
            // never has to wait on a cold network fetch — only ever hits
            // this once per screen since the cubit only loads once.
            for (final cat in state.data) {
              final url = cat.imageUrl ?? '';
              if (url.isEmpty) continue;
              // width/height:50 matches SidebarItem's explicit AppNetworkImage
              // size so this lands in the image cache under the same key
              // build() looks up.
              AppNetworkImage.precache(context, url, width: 50, height: 50);
            }
          }
          if (state is PaginationLoaded<Category> &&
              state.data.isNotEmpty &&
              selectedCategoryId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onAutoSelectCategory(state.data.first);
            });
          }
        },
        builder: (context, state) {
          if (state is PaginationLoading<Category>) {
            return SidebarLoader(bg: sidebarBg);
          }
          if (state is PaginationError<Category>) {
            return Container(
              padding: EdgeInsetsDirectional.all(ThemeConstants.paddingS),
              color: sidebarBg,
              alignment: AlignmentDirectional.center,
              child: AppText(
                state.message,
                style: context.tt.labelSmall?.copyWith(fontSize: 10),
                textAlign: .center,
              ),
            );
          }
          if (state is PaginationLoaded<Category>) {
            return Container(
              color: sidebarBg,
              child: pager.attach(
                ListView.builder(
                  controller: pager.controller,
                  itemCount: state.data.length,
                  itemBuilder: (context, index) {
                    final cat = state.data[index];
                    return SidebarItem(
                      key: _itemKeys.putIfAbsent(
                        cat.id ?? '',
                        () => GlobalKey(),
                      ),
                      category: cat,
                      // A has_child item only reads as "selected" if it's the
                      // one previewed as a grid on the right; otherwise tapping
                      // it drills into its own page instead of showing content
                      // here, so it shouldn't look selected.
                      isSelected:
                          selectedCategoryId == cat.id &&
                          (cat.hasChild != true ||
                              cat.id == autoChildCategoryId),
                      onTap: () => onSelectCategory(cat),
                    );
                  },
                ),
              ),
            );
          }
          return AppSpacing.shrink;
        },
      ),
    );
  }
}
