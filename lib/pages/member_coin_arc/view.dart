import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/member/coin_like_arc/item.dart';
import 'package:PiliPlus/pages/member_coin_arc/controller.dart';
import 'package:PiliPlus/pages/member_coin_arc/widgets/item.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MemberCoinArcPage extends StatefulWidget {
  const MemberCoinArcPage({
    super.key,
    required this.mid,
    this.name,
  });

  final dynamic mid;
  final String? name;

  @override
  State<MemberCoinArcPage> createState() => _MemberCoinArcPageState();
}

class _MemberCoinArcPageState extends State<MemberCoinArcPage> {
  late final mid = Accounts.main.mid;
  late final MemberCoinArcController _ctr;

  @override
  void initState() {
    super.initState();
    _ctr = Get.put(
      MemberCoinArcController(mid: widget.mid),
      tag: Utils.makeHeroTag(widget.mid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return SimpleScaffold(
      appBar: AppBar(
        title: Text(
          '${widget.mid == mid ? '我' : '${widget.name}'}的最近投币',
        ),
      ),
      body: refreshIndicator(
        onRefresh: _ctr.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: 7,
                left: Style.safeSpace + padding.left,
                right: Style.safeSpace + padding.right,
                bottom: padding.bottom + 100,
              ),
              sliver: Obx(() => _buildBody(_ctr.loadingState.value)),
            ),
          ],
        ),
      ),
    );
  }

  /// 桌面端与首页同一算式（动态列数 + 整卡同比，见 [CardGridDelegate]）；
  /// 非桌面端逐字沿用原口径（`baseCardWidth` = 原 `maxCrossAxisExtent`）。
  late final gridDelegate = CardGridDelegate(
    baseCardWidth: Grid.smallCardWidth,
    baseContentExtent: MediaQuery.textScalerOf(context).scale(75),
    mainAxisSpacing: Style.cardSpace,
    crossAxisSpacing: Style.cardSpace,
    childAspectRatio: Style.aspectRatio,
  );

  Widget _buildBody(LoadingState<List<CoinLikeArcItem>?> loadingState) {
    return switch (loadingState) {
      Loading() => SliverGrid(
        gridDelegate: gridDelegate,
        delegate: const SliverSingleChildDelegate(
          count: 16,
          child: VideoCardVSkeleton(),
        ),
      ),
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemCount: response.length,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _ctr.onLoadMore();
                  }
                  // gridDelegate.scaled = 卡片文字随本列实际列宽同比（非桌面端原样返回）
                  return gridDelegate.scaled(
                    MemberCoinLikeItem(item: response[index]),
                  );
                },
              )
            : HttpError(onReload: _ctr.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _ctr.onReload,
      ),
    };
  }
}
