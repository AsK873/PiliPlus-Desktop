import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/grpc/bilibili/im/interfaces/v1.pb.dart'
    show EmotionInfo, RspSessionMsg;
import 'package:PiliPlus/grpc/bilibili/im/type.pb.dart' show Msg, MsgType;
import 'package:PiliPlus/grpc/im.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/msg.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 桌面 Drawer 模式显式传入的会话参数；为 null 的项回落到路由 arguments。
class _DrawerArgs {
  const _DrawerArgs(this.talkerId, this.name, this.face, this.mid, this.isLive);

  final int? talkerId;
  final String? name;
  final String? face;
  final int? mid;
  final bool? isLive;
}

class WhisperDetailController extends CommonListController<RspSessionMsg, Msg> {
  /// 两种进入方式共用本控制器：
  /// - **Drawer 模式**（桌面端右侧抽屉）：由 `WhisperDetailPage` 显式传入 5 个参数；
  /// - **普通路由模式**：保持原有 `Get.arguments` 取值逻辑不变（构造参数为空时兜底）。
  WhisperDetailController({
    int? talkerId,
    String? name,
    String? face,
    int? mid,
    bool? isLive,
  }) : _drawer = _DrawerArgs(talkerId, name, face, mid, isLive);

  final _DrawerArgs _drawer;

  late final account = Accounts.main;

  late final int talkerId;
  late final String name;
  late final String face;
  late final int? mid;
  late final bool isLive;

  Int64? msgSeqno;

  //表情转换图片规则
  List<EmotionInfo>? eInfos;

  @override
  void onInit() {
    super.onInit();
    // Drawer 模式优先用构造参数；普通路由模式继续读路由 arguments（与原实现一致）
    final args = Get.arguments;
    final Map? routeArgs = args is Map ? args : null;
    talkerId = _drawer.talkerId ?? routeArgs?['talkerId'];
    name = _drawer.name ?? routeArgs?['name'];
    face = _drawer.face ?? routeArgs?['face'];
    mid = _drawer.mid ?? routeArgs?['mid'];
    isLive = _drawer.isLive ?? routeArgs?['isLive'] ?? false;
    queryData();
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<RspSessionMsg> response) {
    List<Msg> msgs = response.response.messages;
    if (msgs.isNotEmpty) {
      msgSeqno = msgs.last.msgSeqno;
      if (msgs.length == 1 &&
          msgs.last.msgType == 18 &&
          msgs.last.msgSource == 18) {
        //{content: [{"text":"对方主动回复或关注你前，最多发送1条消息","color_day":"#9499A0","color_nig":"#9499A0"}]}
      } else {
        ackSessionMsg(msgs.last.msgSeqno.toInt());
      }
      msgs.removeWhere((e) => e.msgType == MsgType.EN_MSG_TYPE_DRAW_BACK.value);
      eInfos ??= <EmotionInfo>[];
      eInfos!.addAll(response.response.eInfos);
    }
    return false;
  }

  // 消息标记已读
  Future<void> ackSessionMsg(int msgSeqno) async {
    final res = await MsgHttp.ackSessionMsg(
      talkerId: talkerId,
      ackSeqno: msgSeqno,
    );
    if (!res.isSuccess) {
      res.toast();
    }
  }

  late bool _isSending = false;
  Future<void> sendMsg({
    String? message,
    Map? picMsg,
    required VoidCallback onClearText,
    MsgType? msgType,
    int? index,
  }) async {
    // debug
    // if (loadingState.value case Success(:final response)) {
    //   final list = List.of(response ?? <Msg>[])
    //     ..insert(
    //       0,
    //       Msg.create()..mergeFromProto3Json({
    //         "senderUid": "${account.mid}",
    //         "receiverType": 1,
    //         "receiverId": "$mid",
    //         "msgType": msgType,
    //         "content": jsonEncode({"content": message}),
    //         "msgSeqno": "1",
    //         "timestamp": "${DateTime.now().millisecondsSinceEpoch ~/ 1000}",
    //         "atUids": ["0"],
    //         "msgKey": "2",
    //         "msgSource": msgType,
    //       }),
    //     );
    //   loadingState.value = Success(list);
    // }
    // onClearText();
    // scrollController.jumpToTop();
    // SmartDialog.showToast('发送成功');
    // return;
    assert((message != null) ^ (picMsg != null));
    if (_isSending) return;
    _isSending = true;
    feedBack();
    SmartDialog.dismiss();
    if (!account.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    final res = await ImGrpc.sendMsg(
      senderUid: account.mid,
      receiverId: mid!,
      content: msgType == .EN_MSG_TYPE_DRAW_BACK
          ? message!
          : jsonEncode(picMsg ?? {"content": message!}),
      msgType:
          msgType ?? (picMsg != null ? .EN_MSG_TYPE_PIC : .EN_MSG_TYPE_TEXT),
    );
    SmartDialog.dismiss();
    if (res.isSuccess) {
      if (msgType == .EN_MSG_TYPE_DRAW_BACK) {
        loadingState
          ..value.data![index!].msgStatus = 1
          ..refresh();
        SmartDialog.showToast('撤回成功');
      } else {
        onRefresh();
        onClearText();
        SmartDialog.showToast('发送成功');
      }
    } else {
      res.toast();
    }
    _isSending = false;
  }

  @override
  List<Msg>? getDataList(RspSessionMsg response) {
    if (response.hasMore == 0) {
      isEnd = true;
    }
    return response.messages;
  }

  @override
  Future<void> onRefresh() {
    msgSeqno = null;
    eInfos = null;
    scrollController.jumpToTop();
    return super.onRefresh();
  }

  @override
  Future<LoadingState<RspSessionMsg>> customGetData() =>
      ImGrpc.syncFetchSessionMsgs(
        talkerId: talkerId,
        beginSeqno: msgSeqno != null ? Int64.ZERO : null,
        endSeqno: msgSeqno,
      );

  Future<LoadingState> onReport(Msg item, int reasonType, String reasonDesc) {
    return MsgHttp.imMsgReport(
      accusedUid: item.senderUid.toInt(),
      reasonType: reasonType,
      reasonDesc: reasonDesc,
      comment: {'group_id': 0, 'msg_key': item.msgKey.toString()},
      extra: {"msg_keys": []},
    );
  }
}
