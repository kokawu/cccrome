# Cent Browser 功能优先级与 Chromium 实现映射
更新日期: 2026-03-27

参考页面:
- https://www.centbrowser.cn/features.html

## 当前结论
- 第一阶段先做 6 个 P0 功能: 会话恢复 + 后台标签延迟加载、标签页行为配置、鼠标手势、超级拖拽、快捷键中心、安全模式
- 这 6 个都建议做成 Chromium 原生能力，不建议先靠扩展拼装正式产品
- 设置入口可以逐步挂到 Chromium 现有设置页或新增 WebUI 子页，但功能本体应优先落在浏览器原生模块

## 目标
- 做一个基于 Chromium 的高效率桌面浏览器
- 第一阶段优先复刻 Cent Browser 里最有感知的效率功能
- 后续为 agent 预留接口空间，但当前优先保证浏览器本体的速度、稳定性和可维护性

## 评估标准
- 日常使用频率高
- 用户能明显感知到效率提升
- 适合做成 Chromium 原生能力
- 不会显著增加后续跟进 Chromium 主线的维护成本

## P0: 第一批优先实现

### 1. 会话恢复 + 后台标签延迟加载
- 用户目标: 重启后恢复现场，但不要一次性唤醒所有后台标签。
- 实现形态: Chromium 原生。
- 主模块:
  - `chrome/browser/ui/startup/startup_browser_creator_impl.cc`
    - 启动阶段是否恢复、是否异步恢复、恢复还是新开窗口的入口。
    - 关键入口: `MaybeAsyncRestore()`, `RestoreOrCreateBrowser()`, `DetermineBrowserOpenBehavior()`
  - `chrome/browser/sessions/session_restore.cc`
    - 会话恢复主链路，后台标签延迟加载应直接挂在这里。
    - 关键入口: `NotifySessionRestoreStartedLoadingTabs()`, `OnTabLoaderFinishedLoadingTabs()`
  - `chrome/browser/prefs/session_startup_pref.cc`
    - 启动恢复偏好读写。
    - 关键入口: `RegisterProfilePrefs()`, `SetStartupPref()`, `GetStartupPref()`, `ShouldRestoreLastSession()`
  - `components/sessions/core/tab_restore_service_helper.cc`
    - 历史标签与窗口恢复服务，负责恢复条目的组织与回放。
  - `chrome/common/pref_names.h`
    - 如果增加“后台标签延迟加载”“并发恢复数”等自定义配置，建议在这里补 pref 名称。
  - `chrome/browser/prefs/browser_prefs.cc`
    - 新增 profile 级 pref 的注册入口。
  - `chrome/browser/resources/settings/on_startup_page/*`
    - 如果后面要给用户暴露设置项，优先挂到现有启动设置页。
- 第一版实现方向:
  - 直接复用 Chromium 原生 session restore。
  - 新增自定义 pref: 是否延迟加载后台恢复标签、首次激活时才真正加载、是否限制并发恢复数。
  - 在 `session_restore.cc` 中区分前台标签和后台标签，后台标签先恢复壳和导航状态，实际加载推迟到激活或空闲时。
- 是否适合先做扩展:
  - 不适合。扩展拿不到 Chromium 启动恢复链路，也无法稳定控制 tab loader。
- 风险与后续:
  - 要处理崩溃恢复、固定标签、标签组、启动 URL 与恢复会话混合等场景。
  - 需要补 session restore 相关 browser test。

### 2. 标签页行为配置
- 用户目标: 新标签插入位置、关闭后激活方向、最小标签宽度、标签列表入口等都可配置。
- 实现形态: Chromium 原生。
- 主模块:
  - `chrome/browser/ui/tabs/tab_strip_model.cc`
    - 标签关闭后的激活策略核心就在这里。
    - 关键入口: `DetermineNewSelectedIndex()`, `GetTabIndexAfterClosing()`, `ActivateTabAt()`
  - `chrome/browser/ui/tabs/tab_strip_model.h`
    - 选择、切换、opener 关系等接口定义。
  - `chrome/browser/ui/views/tabs/browser_tab_strip_controller.cc`
    - 负责把 tab UI 操作桥接到 `TabStripModel`。
    - 关键入口: `CreateNewTab()`, `CloseTab()`, `OnTabStripModelChanged()`
  - `chrome/browser/ui/views/tabs/tab_strip.cc`
    - tab strip 行为与视图层交互。
  - `chrome/browser/ui/views/tabs/tab_strip_layout.cc`
  - `chrome/browser/ui/views/tabs/tab_strip_layout_helper.cc`
  - `chrome/browser/ui/views/tabs/tab_width_constraints.cc`
    - 最小宽度、布局压缩策略、tab overflow 行为的主落点。
  - `chrome/common/pref_names.h`
  - `chrome/browser/prefs/browser_prefs.cc`
    - 新增 tab 行为相关 pref。
  - `chrome/browser/resources/settings/appearance_page/*`
    - 第一版设置入口可先挂在外观页，后面再拆专门的标签页行为子页。
- 第一版实现方向:
  - 在 tab 创建链路增加“插入到当前标签右侧 / 插到末尾 / 跟随 opener”的策略分支。
  - 在 `DetermineNewSelectedIndex()` 中增加“关闭后激活左侧 / 右侧 / 最近访问”的 pref 驱动逻辑。
  - 在 layout 层增加最小标签宽度和 overflow 列表入口配置。
- 是否适合先做扩展:
  - 不适合。扩展无法稳定介入原生 tab strip 布局、最小宽度计算和关闭后选中逻辑。
- 风险与后续:
  - 改动要尽量集中在策略层，避免散改 tab strip 全链路。
  - 需要评估 pinned tab、tab group、split tab 与自定义策略的兼容性。

### 3. 鼠标手势
- 用户目标: 用右键轨迹或自定义轨迹完成后退、前进、关闭标签、恢复关闭标签、新标签、切换标签等操作。
- 百分浏览器对齐基线:
  - 按 Cent Browser 功能页中的鼠标手势设置为产品基线，不自创一套完全不同的交互。
  - 首版至少支持这些设置项: 启用鼠标手势、显示手势轨迹、显示手势提示、轨迹颜色、线宽、识别阈值。
  - 首版至少支持这些动作类型: 单向手势、折线手势、往返手势、按住右键滚轮组合、按住右键再点左键或中键的组合动作。
  - 默认动作集合至少覆盖 Cent Browser 截图里出现的高频动作: 上下翻页、后退前进、前后标签切换、关闭当前标签并激活左侧或右侧标签、打开新标签页、打开新的小号标签页、复制地址栏网址、滚动到页顶页底、重新加载、恢复关闭的标签。
  - 第一版默认映射应尽量与 Cent Browser 保持一致，后续再考虑是否提供“经典 / 简化”预设。
- 实现形态: Chromium 原生。
- 主模块:
  - `chrome/browser/ui/views/frame/browser_root_view.cc`
    - 更适合作为桌面浏览器窗口级鼠标事件捕获入口。
  - `chrome/browser/ui/views/frame/browser_root_view.h`
    - RootView 层定义，后续适合挂一个自定义 gesture controller。
  - `chrome/browser/ui/views/frame/browser_view.cc`
    - 已有 `OnGestureEvent()` 到 browser command 的分发模式，可复用命令执行链。
  - `chrome/browser/ui/views/tabs/tab.cc`
    - tab 自身已有鼠标事件，要避免与全局手势冲突。
  - `chrome/app/chrome_command_ids.h`
    - 新增手势可触发的浏览器命令 id。
  - `chrome/browser/ui/browser_command_controller.cc`
  - `chrome/browser/ui/browser_commands.cc`
    - 手势最终执行应统一落到浏览器命令层，而不是散落在各个 view 里。
- 第一版实现方向:
  - 在 `BrowserRootView` 或其附近的 views 事件链捕获右键拖动轨迹。
  - 单独抽一个 `MouseGestureController` 或类似 helper，负责轨迹采样、方向归一化、命令映射。
  - 配置模型按 “手势识别参数 + 手势到动作映射” 两层拆开，避免以后加自定义动作时重构。
  - 首版就把 Cent Browser 那套默认动作表固化进去，不做一个只有 4 个手势的缩水版。
  - 执行动作尽量复用现有 browser command；只有没有现成命令时才补新的 command id。
- 是否适合先做扩展:
  - 可做验证原型，但不建议作为正式路线。
  - 扩展通常只能覆盖网页内容区，覆盖不到标签栏、工具栏、下载栏等浏览器 chrome 区域。
- 风险与后续:
  - 要处理上下文菜单、拖拽、文本选择、触摸板 gesture 的冲突。
  - 首版建议只锁 Windows，后续再考虑跨平台输入差异。

### 4. 超级拖拽
- 用户目标: 拖文字直接搜索，拖链接前台或后台打开，拖资源链接直接下载。
- 实现形态: Chromium 原生。
- 主模块:
  - `chrome/browser/ui/views/frame/browser_root_view.cc`
    - 浏览器窗口级 drop 主入口已经在这里。
    - 关键入口: `OnDragEntered()`, `OnDragUpdated()`, `GetDropCallback()`, `NavigateToDroppedUrls()`
  - `chrome/browser/ui/views/frame/browser_view.cc`
    - 某些 tab strip 或 WebUI tab strip 的拖拽协同逻辑在这里。
  - `content/browser/web_contents/web_contents_impl.cc`
    - 内容侧 drag data、drop data、下载触发的关键链路。
    - 关键入口: `PreHandleDragUpdate()`, `GetDropData()`, `DownloadUrl(...)`
  - `chrome/browser/download/chrome_download_manager_delegate.cc`
    - 下载策略与下载入口控制。
  - `chrome/browser/download/download_target_determiner.cc`
    - 下载目标路径与下载行为确定。
  - `components/omnibox/browser/omnibox_client.cc`
    - `IsPasteAndGoEnabled()` 可作为文本转 URL / 搜索能力边界的参考。
- 第一版实现方向:
  - 在浏览器窗口层先识别拖拽数据类型: 文本、URL、可下载资源。
  - 文本拖拽: 直接走默认搜索引擎。
  - URL 拖拽: 走当前标签、新标签或后台标签导航。
  - 可下载资源: 直接接入下载管理链路。
- 是否适合先做扩展:
  - 可做网页内原型，但不适合作为正式路线。
  - 扩展很难无缝覆盖浏览器 chrome 区域、下载流程和跨区域拖放体验。
- 风险与后续:
  - 需要处理 file/url/text 混合数据、拖放安全过滤、企业策略限制。
  - 要避免与现有 BrowserRootView drop 行为互相覆盖。

### 5. 快捷键中心
- 用户目标: 补齐高频浏览器命令，并支持后续用户自定义热键。
- 实现形态: Chromium 原生，设置界面后续可走 WebUI。
- 主模块:
  - `chrome/app/chrome_command_ids.h`
    - 新命令 id 定义入口。
    - 可直接复用已有命令，例如 `IDC_COPY_URL`, `IDC_PASTE_AND_GO`
  - `chrome/browser/ui/accelerator_table.cc`
    - 默认快捷键映射中心。
    - 关键结构: `kAcceleratorMap`
  - `chrome/browser/ui/browser_command_controller.cc`
    - 命令是否可执行、如何分发执行。
  - `chrome/browser/ui/browser_commands.cc`
    - 浏览器命令具体实现。
  - `components/omnibox/browser/omnibox_client.cc`
    - 地址栏相关动作能力边界，比如 `IsPasteAndGoEnabled()`
  - `chrome/common/pref_names.h`
  - `chrome/browser/prefs/browser_prefs.cc`
    - 如果后续支持用户级热键覆盖，需要新增 pref 持久化。
  - `chrome/browser/ui/webui/settings/*`
  - `chrome/browser/resources/settings/*`
    - 后续可新增“快捷键中心”设置页或子页。
- 第一版实现方向:
  - 先补 4 到 6 个最高频命令: 最近访问标签、显示标签列表、复制标题和 URL、粘贴并打开、粘贴并搜索。
  - 有现成命令 id 的直接绑定，没有的再补 `chrome_command_ids.h` 和 `browser_commands.cc`。
  - 第二阶段再做用户自定义绑定、冲突检测和导入导出。
- 是否适合先做扩展:
  - 局部可以，但不建议作为正式路线。
  - 扩展 command API 无法完整覆盖浏览器原生命令矩阵，也不方便统一处理冲突。
- 风险与后续:
  - 快捷键冲突处理要单独设计。
  - 平台差异较大，首版建议先把 Windows 规则做稳。

### 6. 安全模式
- 用户目标: 一键用保守配置重启浏览器，快速判断问题是来自扩展、自定义功能还是用户配置。
- 实现形态: Chromium 原生。
- 主模块:
  - `chrome/browser/lifetime/application_lifetime.cc`
    - 重启与重启请求入口。
    - 关键入口: `AttemptRelaunch()`, `AttemptRestart()`
  - `chrome/browser/lifetime/application_lifetime_desktop.cc`
    - 桌面端实际重启实现。
    - 关键入口: `AttemptRestartInternal(...)`
  - `chrome/browser/lifetime/browser_shutdown.cc`
    - restart mode、重启时命令行开关修改与会话恢复标记。
  - `chrome/browser/ui/startup/startup_browser_creator.cc`
    - 重启后启动分支和恢复判断。
  - `chrome/browser/extensions/extension_service.cc`
    - 已有 `--disable-extensions` / `--disable-extensions-except` 相关逻辑可复用。
  - `chrome/browser/ui/startup/bad_flags_prompt.cc`
    - 启动参数异常提示和安全提示可参考。
- 第一版实现方向:
  - UI 提供“以安全模式重启”入口。
  - 最小能力集合: 重启时附带 `--disable-extensions`。
  - 建议额外增加自定义开关，例如 `--cc-safe-mode`，启动时关闭自定义增强功能、载入保守 pref，并在 UI 上明确标识当前处于安全模式。
- 是否适合先做扩展:
  - 完全不适合。扩展无法把自己和其他扩展一起安全重启出去。
- 风险与后续:
  - 需要先定义“安全模式到底禁用哪些自定义能力”。
  - 需要提供一键退出安全模式并恢复正常启动的入口。

## P1: 第二批可做

### 1. 下载行为增强
- 价值: 中高
- 说明: 能提升体验，但第一版不必做得太重。

### 2. 启动页 / 新标签页自定义
- 价值: 中高
- 说明: 用户感知强，后续也适合和 agent 入口结合。

### 3. 老板键 / 窗口置顶
- 价值: 中
- 说明: 有用户群，但不是主路径能力。

### 4. 地址栏与搜索行为细调
- 价值: 中
- 说明: 属于体验细节，优先级低于标签和交互效率能力。

### 5. 自定义 CSS
- 价值: 中
- 说明: 更偏进阶用户，后续再做更稳。

### 6. WebRTC 等隐私开关
- 价值: 中
- 说明: 可做增强项，但不是第一阶段核心卖点。

## P2: 暂不优先

### 1. 多行标签栏
- 价值: 有吸引力
- 风险: UI 改动较重，后续跟 Chromium 主线同步成本高。

### 2. IE 打开当前页
- 结论: 不优先
- 原因: 现代场景价值偏低。

### 3. Flash 相关能力
- 结论: 不做
- 原因: 已经过时。

### 4. 过多兼容性开关
- 结论: 不优先
- 原因: 容易增加维护负担，收益有限。

### 5. 激进内存优化或单进程类选项
- 结论: 不优先
- 原因: 容易引入稳定性问题。

## 工程实现建议
- 先做一层统一的自定义 pref 和 feature 开关，不要每个功能各自散落存配置。
- 先把功能本体做成 Chromium 原生命令或策略层，再考虑把设置入口补到 WebUI。
- 优先减少“全局散改”，尽量在 tab、startup、command、root view 这些已有核心节点上落点。
- 第一轮尽量先锁 Windows，避免同时处理多平台输入和系统集成差异。

## 后续给 agent 预留的接口位
- 这一步先不做公网开放 API，先把浏览器内部命令层整理好。
- 后续最值得抽象成 agent 接口的是:
  - 标签枚举、激活、关闭、移动
  - 新开页面、搜索、下载
  - 执行浏览器命令 id
  - 读取当前页面标题、URL、选中文本
- 工程建议:
  - 先把 P0 功能统一沉到 browser command / tab model / browser view 这几层。
  - 等第一批功能稳定后，再决定暴露成 extension API、Native Messaging、WebSocket 或本地 IPC。

## 当前建议
- 第一阶段先盯住这 6 个核心功能。
- 这 6 个最接近 Cent Browser 的核心体验，也最符合“方便、好用、快速、不拖沓”的目标。
- 其中鼠标手势不降级到第二波，直接按 Cent Browser 基线进入第一版能力范围。
- 下一步可以直接从这份文档继续拆: 每个功能的 pref 设计、命令设计、UI 入口、测试计划。
