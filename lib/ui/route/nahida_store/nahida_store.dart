import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:genshin_mod_manager/data/helper/path_op_string.dart';
import 'package:genshin_mod_manager/di/nahida_store.dart';
import 'package:genshin_mod_manager/domain/entity/akasha.dart';
import 'package:genshin_mod_manager/domain/entity/mod_category.dart';
import 'package:genshin_mod_manager/ui/util/display_infobar.dart';
import 'package:genshin_mod_manager/ui/util/open_url.dart';
import 'package:genshin_mod_manager/ui/util/tag_parser.dart';
import 'package:genshin_mod_manager/ui/widget/intrinsic_command_bar.dart';
import 'package:genshin_mod_manager/ui/widget/thick_scrollbar.dart';
import 'package:genshin_mod_manager/ui/widget/third_party/flutter/min_extent_delegate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

part 'store_element.dart';

class NahidaStoreRoute extends StatefulHookConsumerWidget {
  const NahidaStoreRoute({required this.category, super.key});

  final ModCategory category;

  @override
  ConsumerState<NahidaStoreRoute> createState() => _NahidaStoreRouteState();

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ModCategory>('category', category));
  }
}

class _NahidaStoreRouteState extends ConsumerState<NahidaStoreRoute> {
  final _textEditingController = TextEditingController();
  TagParseElement? _tagFilter;
  final _debouncer = _Debouncer(const Duration(milliseconds: 500));

  final PagingController<int, NahidaliveElement?> _pagingController =
      PagingController(firstPageKey: 1);

  Future<void> _fetchPage(final int pageKey) async {
    try {
      final newItems =
          await ref.read(akashaApiProvider).fetchNahidaliveElements(pageKey);
      final isLastPage = newItems.isEmpty;
      List<NahidaliveElement?> filteredItems =
          newItems.where(_dataFilter).toList();
      if (newItems.isNotEmpty && filteredItems.isEmpty && pageKey == 1) {
        filteredItems = [null];
      }
      print(newItems.length);
      if (isLastPage) {
        print('last page');
        _pagingController.appendLastPage(filteredItems);
      } else {
        final nextPageKey = pageKey + 1;
        print('next page $nextPageKey');
        _pagingController.appendPage(filteredItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
    ref.read(downloadModelProvider).registerDownloadCallbacks(
      onApiException: (final e) {
        if (!mounted) {
          return;
        }
        unawaited(
          displayInfoBarInContext(
            context,
            title: const Text('Download failed'),
            content: Text('${e.uri}'),
            severity: InfoBarSeverity.error,
          ),
        );
      },
      onDownloadComplete: (final element) {
        if (!mounted) {
          return;
        }
        unawaited(
          displayInfoBarInContext(
            context,
            title: Text('Downloaded ${element.title}'),
            severity: InfoBarSeverity.success,
          ),
        );
      },
      onPasswordRequired: (final wrongPw) async {
        if (!mounted) {
          return Future(() => null);
        }
        return showDialog(
          context: context,
          builder: (final dialogContext) => ContentDialog(
            title: const Text('Enter password'),
            content: IntrinsicHeight(
              child: TextFormBox(
                autovalidateMode: AutovalidateMode.always,
                autofocus: true,
                controller: _textEditingController,
                placeholder: 'Password',
                onFieldSubmitted: (final value) => Navigator.of(dialogContext)
                    .pop(_textEditingController.text),
                validator: (final value) {
                  if (wrongPw == null || value == null) {
                    return null;
                  }
                  if (value == wrongPw) {
                    return 'Wrong password';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              Button(
                onPressed: Navigator.of(dialogContext).pop,
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(_textEditingController.text),
                child: const Text('Download'),
              ),
            ],
          ),
        );
      },
      onExtractFail: (final category, final modName, final data) async {
        if (mounted) {
          unawaited(
            displayInfoBarInContext(
              context,
              title: const Text('Download failed'),
              content: Text('Failed to extract archive: decode error.'
                  ' Instead, the archive was saved as $modName.'),
              severity: InfoBarSeverity.error,
            ),
          );
        }
        try {
          await File(category.path.pJoin(modName)).writeAsBytes(data);
        } on Exception catch (e) {
          if (!mounted) {
            return;
          }
          unawaited(
            displayInfoBarInContext(
              context,
              title: const Text('Write failed'),
              content: Text('Failed to write archive $modName: $e'),
              severity: InfoBarSeverity.error,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => ScaffoldPage.withPadding(
        header: PageHeader(
          title: Text('${widget.category.name} ← Akasha'),
          leading: _buildLeading(),
          commandBar: _buildCommandBar(),
        ),
        content: _buildContent(),
      );

  Widget? _buildLeading() => context.canPop()
      ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: RepaintBoundary(
            child: IconButton(
              icon: const Icon(FluentIcons.back),
              onPressed: context.pop,
            ),
          ),
        )
      : null;

  Widget _buildCommandBar() => RepaintBoundary(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(child: _buildSearchBox()),
            const SizedBox(width: 16),
            _buildCommandBarCard(),
          ],
        ),
      );

  Widget _buildCommandBarCard() => IntrinsicCommandBarCard(
        child: CommandBar(
          overflowBehavior: CommandBarOverflowBehavior.clip,
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              onPressed: _onRefresh,
            ),
          ],
        ),
      );

  Widget _buildSearchBox() => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: TextFormBox(
          autovalidateMode: AutovalidateMode.always,
          placeholder: 'Search tags',
          onChanged: _onSearchChange,
          validator: _onValidationCheck,
        ),
      );

  Widget _buildContent() => ThickScrollbar(
        child: PagedGridView<int, NahidaliveElement?>(
          pagingController: _pagingController,
          gridDelegate: SliverGridDelegateWithMinCrossAxisExtent(
            minCrossAxisExtent: 500,
            mainAxisExtent: 500,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          builderDelegate: PagedChildBuilderDelegate(
            itemBuilder: (final context, final item, final index) {
              if (item == null) {
                return const Center(
                  child: Text('Not found in the first page. Searching more...'),
                );
              }
              return RevertScrollbar(
                child: StoreElement(
                  passwordController: _textEditingController,
                  element: item,
                  category: widget.category,
                ),
              );
            },
          ),
        ),
      );

  void _onRefresh() {
    _pagingController.refresh();
  }

  String? _onValidationCheck(final String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      parseTagQuery(value);
    } on Exception catch (e) {
      return e.toString();
    }
    return null;
  }

  void _onSearchChange(final String value) {
    TagParseElement? filter;
    try {
      filter = parseTagQuery(value);
    } on Exception {
      filter = null;
    }
    _debouncer(
      () {
        setState(() {
          _tagFilter = filter;
          _pagingController.refresh();
        });
      },
    );
  }

  bool _dataFilter(final NahidaliveElement element) {
    final tagMap = {for (final e in element.tags) e};
    final filter = _tagFilter;
    if (filter == null) {
      return true;
    }
    try {
      return filter.evaluate(tagMap);
    } on Exception {
      return true;
    }
  }
}

class _Debouncer {
  _Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void call(final VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }
}
