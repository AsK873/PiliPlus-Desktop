import 'dart:async';
import 'dart:io' show File;

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/widgets/dialog/report.dart';
import 'package:PiliPlus/common/widgets/flutter/chat_list_view.dart';
import 'package:PiliPlus/common/widgets/flutter/text_field/text_field.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show platformAlwaysClampingPhysics;
import 'package:PiliPlus/grpc/bilibili/im/type.pb.dart' show Msg;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/msg.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/pages/common/publish/common_rich_text_pub_page.dart';
import 'package:PiliPlus/pages/emote/view.dart';
import 'package:PiliPlus/pages/whisper_detail/controller.dart';
import 'package:PiliPlus/pages/whisper_detail/widget/chat_item.dart';
import 'package:PiliPlus/pages/whisper_link_setting/view.dart';
import 'package:PiliPlus/utils/extension/file_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart' hide TextField;
import 'package:mime/mime.dart';

const _kMaxExtent = 625.0;
const _kConstraints = BoxConstraints(maxWidth: _kMaxExtent);

class WhisperDetailPage extends CommonRichTextPubPage {
  const WhisperDetailPage({
    super.key,
    super.autofocus = false,
    this.talkerId,
    this.name,
    this.face,
    this.mid,
    this.isLive,
    this.isDrawer = false,
    this.onClose,
  });

  /// 以下 5 项仅在**桌面右侧 Drawer** 模式显式传入；
  /// 为空时（普通路由模式）控制器仍按原逻辑读取 `Get.arguments`。
  final int? talkerId;
  final String? name;
  final String? face;
  final int? mid;
  final bool? isLive;

  /// 是否由桌面端右侧 Drawer 承载（仅影响返回按钮：改为关闭 Drawer，而非 pop 路由）
  final bool isDrawer;

  /// Drawer 模式的关闭回调（关闭当前 Drawer）
  final VoidCallback? onClose;

  @override
  State<WhisperDetailPage> createState() => _WhisperDetailPageState();
}

class _WhisperDetailPageState
    extends CommonRichTextPubPageState<WhisperDetailPage> {
  /// 控制器注册 tag（与改动前保持同一算法：`Utils.makeHeroTag(...)`）
  late final String _tag;
  late final WhisperDetailController _whisperDetailController;

  @override
  void initState() {
    super.initState();
    _tag = Utils.makeHeroTag(widget.talkerId ?? Get.parameters['talkerId']);
    _whisperDetailController = Get.put(
      WhisperDetailController(
        talkerId: widget.talkerId,
        name: widget.name,
        face: widget.face,
        mid: widget.mid,
        isLive: widget.isLive,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    // 桌面 Drawer 模式没有路由可依赖（tag 每次随机，不会自动回收）：
    // 页面卸载时显式回收本会话控制器，避免残留/下一次打开出现旧会话。
    // 普通路由模式仍由 GetX 路由生命周期管理，行为不变。
    if (widget.isDrawer) {
      Get.delete<WhisperDetailController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    late final containerColor = ElevationOverlay.colorWithOverlay(
      theme.colorScheme.surface,
      theme.hoverColor,
      1,
    );
    return SimpleScaffold(
      appBar: AppBar(
        // Drawer 模式：显式提供关闭按钮，关闭当前 Drawer（不 pop 根 /whisper 路由），
        // 与私信页自身 `desktopEmbedded ? BackButton(onPressed: _handleBack) : null` 同款；
        // 普通路由模式保持 leading 为 null（仍由框架给出默认返回箭头）。
        leading: widget.isDrawer && widget.onClose != null
            ? BackButton(onPressed: widget.onClose)
            : null,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_whisperDetailController.mid != null) {
              feedBack();
              Get.toNamed('/member?mid=${_whisperDetailController.mid}');
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NetworkImgLayer(
                width: 34,
                height: 34,
                type: ImageType.avatar,
                src: _whisperDetailController.face,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _whisperDetailController.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1, fontSize: 16),
                  strutStyle: const StrutStyle(
                    leading: 0,
                    height: 1,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_whisperDetailController.isLive) ...[
                const SizedBox(width: 10),
                Image.asset(
                  Assets.livingRect,
                  height: 16,
                  cacheHeight: 16.cacheSize(context),
                  filterQuality: FilterQuality.low,
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => Get.to(
              WhisperLinkSettingPage(
                talkerUid: _whisperDetailController.talkerId,
              ),
            ),
            icon: Icon(
              size: 22,
              Icons.settings,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: Column(
          children: [
            Expanded(
              child: Listener(
                onPointerDown: hidePanel,
                behavior: .opaque,
                child: Obx(
                  () => _buildBody(_whisperDetailController.loadingState.value),
                ),
              ),
            ),
            if (_whisperDetailController.mid != null) ...[
              ConstrainedBox(
                constraints: _kConstraints,
                child: _buildInputView(containerColor),
              ),
              ConstrainedBox(
                constraints: _kConstraints,
                child: buildPanelContainer(containerColor),
              ),
            ] else
              SizedBox(height: padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<Msg>?> loadingState) {
    return switch (loadingState) {
      Loading() => m3eLoading,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? ChatListView.separated(
                maxExtent: _kMaxExtent,
                itemCount: response.length,
                padding: const .all(kChatListPadding),
                physics: platformAlwaysClampingPhysics,
                controller: _whisperDetailController.scrollController,
                itemBuilder: (context, int index) {
                  if (index == response.length - 1) {
                    _whisperDetailController.onLoadMore();
                  }
                  final item = response[index];
                  final isOwner =
                      item.senderUid.toInt() ==
                      _whisperDetailController.account.mid;
                  return ChatItem(
                    item: item,
                    eInfos: _whisperDetailController.eInfos,
                    // 桌面端长按 = 无动作（消息菜单仍由右键 onSecondaryTapUp 提供）
                    onLongPress: PlatformUtils.isMobile
                        ? () => onLongPress(index, item, isOwner)
                        : null,
                    onSecondaryTapUp: PlatformUtils.isDesktop
                        ? (e) =>
                              _showMenu(e.globalPosition, index, item, isOwner)
                        : null,
                    isOwner: isOwner,
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
              )
            : scrollErrorWidget(onReload: _whisperDetailController.onReload),
      Error(:final errMsg) => scrollErrorWidget(
        errMsg: errMsg,
        onReload: _whisperDetailController.onReload,
      ),
    };
  }

  void _showMenu(Offset offset, int index, Msg item, bool isOwner) {
    showMenu(
      context: context,
      position: PageUtils.menuPosition(offset),
      items: [
        if (isOwner)
          PopupMenuItem(
            height: 42,
            onTap: () => _whisperDetailController.sendMsg(
              message: '${item.msgKey}',
              onClearText: editController.clear,
              msgType: .EN_MSG_TYPE_DRAW_BACK,
              index: index,
            ),
            child: const Text('撤回', style: TextStyle(fontSize: 14)),
          )
        else
          PopupMenuItem(
            height: 42,
            onTap: () => onReport(item),
            child: const Text('举报', style: TextStyle(fontSize: 14)),
          ),
      ],
    );
  }

  void onReport(Msg item) {
    autoWrapReportDialog(
      context,
      ban: false,
      ReportOptions.imMsgReport,
      (reasonType, reasonDesc, banUid) => _whisperDetailController.onReport(
        item,
        reasonType,
        reasonDesc ?? ReportOptions.imMsgReport['']![reasonType]!,
      ),
    );
  }

  void onLongPress(int index, Msg item, bool isOwner) {
    Feedback.forLongPress(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: isOwner
            ? ListTile(
                onTap: () {
                  // 关闭本弹窗（不是页面返回）：Drawer / 路由两种模式行为一致，
                  // 均只 pop 掉这个 AlertDialog，不会影响 /whisper 路由或 Drawer。
                  Get.back();
                  _whisperDetailController.sendMsg(
                    message: '${item.msgKey}',
                    onClearText: editController.clear,
                    msgType: .EN_MSG_TYPE_DRAW_BACK,
                    index: index,
                  );
                },
                dense: true,
                title: const Text('撤回', style: TextStyle(fontSize: 14)),
              )
            : ListTile(
                onTap: () {
                  // 同上：只关闭弹窗，不影响 /whisper 路由或 Drawer
                  Get.back();
                  onReport(item);
                },
                dense: true,
                title: const Text('举报', style: TextStyle(fontSize: 14)),
              ),
      ),
    );
  }

  Widget _buildInputView(Color containerColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () =>
                updatePanelType(panelType.value == .emoji ? .keyboard : .emoji),
            icon: const Icon(Icons.emoji_emotions),
            tooltip: '表情',
          ),
          Expanded(
            child: Obx(
              () => RichTextField(
                key: key,
                readOnly: readOnly.value,
                focusNode: focusNode,
                controller: editController,
                minLines: 1,
                maxLines: 4,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  filled: true,
                  hintText: '发个消息聊聊呗~',
                  fillColor: theme.colorScheme.surface,
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                    gapPadding: 0,
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
                // inputFormatters: [LengthLimitingTextInputFormatter(500)],
              ),
            ),
          ),
          Obx(
            () {
              final enablePublish = this.enablePublish.value;
              return IconButton(
                onPressed: () async {
                  if (enablePublish) {
                    _whisperDetailController.sendMsg(
                      message: editController.rawText,
                      onClearText: () {
                        editController.clear();
                        this.enablePublish.value = false;
                      },
                    );
                  } else {
                    try {
                      final pickedFile = await imagePicker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 100,
                        requestFullMetadata: false,
                      );
                      if (pickedFile != null) {
                        final path = pickedFile.path;
                        SmartDialog.showLoading(msg: '正在上传图片');
                        final result = await MsgHttp.uploadBfs(
                          path: path,
                          biz: 'im',
                        );
                        if (result case Success(:final response)) {
                          final mimeType =
                              lookupMimeType(
                                path,
                              )?.split('/').elementAtOrNull(1) ??
                              'jpg';
                          final picMsg = {
                            'url': response.imageUrl,
                            'height': response.imageHeight,
                            'width': response.imageWidth,
                            'imageType': mimeType,
                            'original': 1,
                            'size': response.imgSize,
                          };
                          SmartDialog.showLoading(msg: '正在发送');
                          await _whisperDetailController
                              .sendMsg(
                                picMsg: picMsg,
                                onClearText: editController.clear,
                              )
                              .whenComplete(() {
                                if (PlatformUtils.isMobile) {
                                  File(path).tryDel();
                                }
                              });
                        } else {
                          SmartDialog.dismiss();
                          result.toast();
                          return;
                        }
                      }
                    } catch (e) {
                      SmartDialog.showToast(e.toString());
                    }
                  }
                },
                icon: Icon(
                  enablePublish
                      ? Icons.send
                      : Icons.add_photo_alternate_outlined,
                ),
                tooltip: enablePublish ? '发送' : '图片',
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget? get customPanel => EmotePanel(onChoose: onChooseEmote);

  @override
  Future<void> onCustomPublish({List? pictures}) {
    throw UnimplementedError();
  }

  @override
  Future<void>? onMention([bool fromClick = false]) => null;

  @override
  void onSave() {}
}
