import 'package:PiliPlus/common/widgets/desktop/desktop_tokens.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show VoteCard;
import 'package:PiliPlus/pages/dynamics/widgets/vote.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

Widget buildVoteCard(
  BuildContext context,
  ColorScheme colorScheme,
  VoteCard voteCard,
) {
  // 桌面播放器右栏：评论区的投票卡片文字与「数据」同一字号基准
  final bool isSidePanel = PlatformUtils.isDesktop && !context.isPortrait;
  return InkWell(
    onTap: () => showVoteDialog(context, voteCard.voteId.toInt()),
    child: Padding(
      padding: const .symmetric(horizontal: 12, vertical: 6),
      child: Row(
        spacing: 10,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.onInverseSurface,
              borderRadius: const .all(.circular(8)),
            ),
            width: 60,
            height: 42,
            child: Icon(
              Icons.bar_chart_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  voteCard.title,
                  maxLines: 1,
                  overflow: .ellipsis,
                  // 右栏：投票标题与「数据」同号（移动端沿用主题默认）
                  style: TextStyle(
                    fontSize: DesktopTokens.replyTextFs(isSidePanel, null),
                  ),
                ),
                Text(
                  '${NumUtils.numFormat(voteCard.count.toInt())}人参与',
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: TextStyle(
                    // 右栏：参与人数与「数据」同号（移动端保持原有 13）
                    fontSize: DesktopTokens.replyTextFs(isSidePanel, 13),
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
