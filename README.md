<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png">
</div>



<div align="center">
    <h1>PiliPlus</h1>
<div align="center">
    <p>使用Flutter开发的BiliBili第三方windows客户端</p>
    <p align="center">
<p align="center">
  <img src="https://github.com/user-attachments/assets/acb91f16-2d87-4a36-9b8e-085cf094474c" width="49%" />
  <img src="https://github.com/user-attachments/assets/3d2a7494-9d44-40e2-957e-01ba99d7e888" width="49%" />
</p>
    </p>
 <img width="2560" height="1392" alt="屏幕截图 2026-10-06 091009" src="https://github.com/user-attachments/assets/863cf357-cc8b-46cd-acfe-d38d8a7e1eca" />




<img width="200" height="200" src="assets/images/logo/logo.png">

</div>

<div align="center">

<h1>PiliPlus</h1>

<div align="center">

<p>使用Flutter开发的BiliBili第三方Windows客户端</p>

<p align="center">

<p align="center">

<img src="https://github.com/user-attachments/assets/acb91f16-2d87-4a36-9b8e-085cf094474c" width="49%" />

<img src="https://github.com/user-attachments/assets/3d2a7494-9d44-40e2-957e-01ba99d7e888" width="49%" />

</p>

</p>

<img width="2560" height="1392" alt="屏幕截图 2026-10-06 091009" src="https://github.com/user-attachments/assets/863cf357-cc8b-46cd-acfe-d38d8a7e1eca" />

</div>

<br/>

## 主要改动

本版本主要针对 **Windows 桌面端的 UI、UX、窗口适配以及播放器体验**进行了较大幅度的调整。

### 🖥️ 桌面端 UI

* 重新设计桌面端侧栏及导航结构
* 建立统一的桌面端 UI 尺寸体系
* 统一桌面端字号、间距、圆角及组件尺寸
* 优化 Windows 高 DPI / 缩放环境下的显示效果
* 优化普通窗口与最大化窗口下的页面布局
* 首页及其他页面卡片采用统一的桌面端缩放逻辑
* 优化桌面端内容区域宽度及页面留白
* 深色 / 浅色主题适配

### 📌 桌面端侧栏

* 新增桌面端固定侧栏
* 优化侧栏图标、文字及间距
* 调整侧栏宽度及导航结构
* 部分功能改为在主页面内嵌展示
* 私信与消息统一为桌面端侧滑面板
* 侧滑面板从侧栏边缘展开，减少页面跳转

### 👤 用户页面

* 优化桌面端用户信息布局
* 用户头像支持打开右侧信息 Drawer
* 优化个人页面内容区域
* 增加「合集和系列」入口
* 优化历史记录、稍后再看、收藏等桌面端内容展示

### ▶️ 播放器

针对 Windows 桌面端重新调整播放器布局及交互。

* 优化普通窗口及最大化状态下的播放器布局
* 修复部分窗口状态切换后播放器区域显示异常的问题
* 优化播放器与右侧信息栏的空间分配
* 优化鼠标操作及手势识别
* 修复鼠标轻微移动可能影响点击操作的问题
* 优化窗口状态变化时的输入处理
* 视频标题支持鼠标选择及复制

### 📋 播放器右侧面板

重新整理播放器右侧信息结构：

```text
UP主
标题
视频数据

点赞 / 点踩 / 投币 / 收藏 / 稍后再看 / 转发

相关推荐

播放列表
```

* 放大右侧面板整体视觉层级
* 统一标题、数据、相关推荐等区域的字号与间距
* 调整「三连」操作区域位置
* 「相关推荐」移动至三连操作下方
* 播放列表与相关推荐重新排列
* 减少相关推荐区域不必要的留白
* 优化推荐卡片与播放列表的文字对齐
* 三连按钮保持紧凑的默认尺寸，避免操作区域过度膨胀

### 📑 播放列表与选集

* 播放列表从顶部工具区域独立出来
* 优化播放列表在右侧面板中的占用空间
* 支持在有限区域内滚动浏览
* 增加「选集」入口
* 选集入口显示当前集数及视频总数量
* 优化选集与播放列表之间的关系

### 🔗 相关推荐

* 调整相关推荐在右侧面板中的位置
* 推荐内容移动至三连操作区域下方
* 减少推荐卡片之间的无效空白
* 优化推荐卡片文字布局
* 与播放列表保持统一的文字对齐方式
* 优化桌面端推荐卡片尺寸

### 🖱️ 鼠标交互

针对 Windows 桌面操作方式进行了适配：

* 缩略图支持鼠标右键菜单
* 缩略图支持长按操作
* 评论图片支持桌面端查看
* 视频标题支持选择 / 复制
* 优化播放器鼠标点击与拖动行为
* 优化播放器手势识别
* 优化窗口最大化后的鼠标输入稳定性

### ⋯ 播放器菜单

整理播放器相关操作：

* 查看封面
* AI总结
* 稍后再看

同时针对桌面窗口调整菜单展开方向，避免菜单超出播放器区域。

<br/>

## 适配平台

* [x] Windows

[![Packaging status](https://repology.org/badge/vertical-allrepos/piliplus.svg)](https://repology.org/project/piliplus/versions)

<br/>

## 下载

可以通过右侧 Release 进行下载或拉取代码到本地进行编译。

<br/>

## 声明

此项目（PiliPlus）是个人为了兴趣而开发，仅用于学习和测试，请于下载后24小时内删除。

所用API皆从官方网站收集，不提供任何破解内容。

在此致敬原作者：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)

在此致敬上游作者：[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)

本仓库做了更激进的修改，感谢原作者的开源精神。

感谢使用。

<br/>

## 致谢

* [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
* [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
* [media-kit](https://github.com/media-kit/media-kit)
* [dio](https://pub.dev/packages/dio)
* 等等

<br/>
<br/>
<br/>

## Star History

<a href="https://star-history.dera.page/#bggRGjQaUbCoE/PiliPlus&Date">

<picture>

<source media="(prefers-color-scheme: dark)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date&theme=dark" />

<source media="(prefers-color-scheme: light)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />

<img alt="Star History Chart" src="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />

</picture>

</a>
