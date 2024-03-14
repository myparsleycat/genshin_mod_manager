import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:genshin_mod_manager/domain/entity/mod.dart';
import 'package:genshin_mod_manager/domain/entity/mod_category.dart';
import 'package:genshin_mod_manager/ui/constant.dart';
import 'package:genshin_mod_manager/ui/route/category/category_vm.dart';
import 'package:genshin_mod_manager/ui/route/category/mod_card.dart';
import 'package:genshin_mod_manager/ui/widget/category_drop_target.dart';
import 'package:genshin_mod_manager/ui/widget/intrinsic_command_bar.dart';
import 'package:genshin_mod_manager/ui/widget/preset_control/preset_control.dart';
import 'package:genshin_mod_manager/ui/widget/thick_scrollbar.dart';
import 'package:genshin_mod_manager/ui/widget/third_party/flutter/min_extent_delegate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CategoryRoute extends StatelessWidget {
  CategoryRoute({
    required this.category,
  }) : super(key: Key(category.name));
  final ModCategory category;

  @override
  Widget build(final BuildContext context) => ChangeNotifierProvider(
        create: (final context) => createCategoryRouteViewModel(
          appStateService: context.read(),
          rootObserverService: context.read(),
          category: category,
        ),
        child: _CategoryRoute(category: category),
      );

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ModCategory>('category', category));
  }
}

class _CategoryRoute extends StatelessWidget {
  const _CategoryRoute({required this.category});

  static const minCrossAxisExtent = 440.0;
  static const mainAxisExtent = 400.0;
  final ModCategory category;

  @override
  Widget build(final BuildContext context) => CategoryDropTarget(
        category: category,
        child: ScaffoldPage(
          header: _buildHeader(context),
          content: _buildContent(),
        ),
      );

  Widget _buildHeader(final BuildContext context) {
    final viewModel = context.read<CategoryRouteViewModel>();
    return PageHeader(
      title: Text(category.name),
      commandBar: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PresetControlWidget(
            isLocal: true,
            category: category,
          ),
          const SizedBox(width: 16),
          IntrinsicCommandBarCard(
            child: CommandBar(
              overflowBehavior: CommandBarOverflowBehavior.clip,
              primaryItems: [
                CommandBarButton(
                  icon: const Icon(FluentIcons.folder_open),
                  onPressed: viewModel.onFolderOpen,
                ),
                CommandBarButton(
                  icon: const Icon(FluentIcons.download),
                  onPressed: () =>
                      context.push(kNahidaStoreRoute, extra: category),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() => ThickScrollbar(
        child: Selector<CategoryRouteViewModel, List<Mod>?>(
          selector: (final context, final vm) => vm.modPaths,
          builder: (final context, final value, final child) {
            if (value == null) {
              return const Center(child: ProgressRing());
            }
            final children = value.map((final e) => ModCard(mod: e)).toList();
            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithMinCrossAxisExtent(
                minCrossAxisExtent: minCrossAxisExtent,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: mainAxisExtent,
              ),
              itemCount: children.length,
              itemBuilder: (final context, final index) => children[index],
            );
          },
        ),
      );

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ModCategory>('category', category));
  }
}
