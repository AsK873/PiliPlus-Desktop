import 'package:PiliPlus/utils/storage_pref.dart';

enum MemberTabType {
  def('默认'),
  home('主页'),
  dynamic('动态'),
  contribute('投稿'),
  favorite('收藏'),
  bangumi('番剧'),
  cheese('课堂'),
  shop('小店'),

  /// 个人主页一级 Tab「合集和系列」。
  ///
  /// 必须存在于本枚举内，否则 `MemberController.customHandleResponse` 中的
  /// `tab2?.retainWhere((item) => MemberTabType.contains(item.param!))` 会把它过滤掉。
  /// 追加在末尾：不改动既有枚举值的下标，`Pref.memberTab` 的存量取值不受影响。
  ugcSeason('合集和系列'),
  ;

  /// 个人主页一级 Tab「合集和系列」的默认标题
  /// （`member_contribute` 子页签复用同一文案）
  static const String ugcSeasonTitle = '合集和系列';

  static bool showMemberShop = Pref.showMemberShop;

  static bool contains(String type) {
    if (type == shop.name && !showMemberShop) {
      return false;
    }
    for (final e in MemberTabType.values) {
      if (e.name == type) {
        return true;
      }
    }
    return false;
  }

  final String title;
  const MemberTabType(this.title);
}
