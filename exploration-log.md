# Research Twin 首次项目探索全过程记录

> 刘炜，2026-05-14  
> 面向学生展示：AI 辅助科研的完整工作流、边界条件、与工程判断

---

## 阶段一：环境衔接与会话初始化（约 5 轮）

### 做了什么

系统首先读取了两份配置文件：`cc-miniconda-connect.md`（Miniconda 环境规则）和 `research-twin-dro-start.md`（科研分身启动指令）。后者定义了角色（DRO 科研助手）、Token 节省规则、以及本地文件读取优先级。

### 关键发现

本地 `~/Projects/` 目录不存在，`awesome-DRO` 等预设仓库未克隆。系统记忆中存有刘炜的基本档案（DRO + 电力系统，Julia 1.12 + MATLAB + Gurobi 12.0.3）。

### 决策点

系统提出三条建议，刘炜选择执行其中两条：(a) 克隆 awesome-DRO 仓库，(c) 创建项目索引文件。

### 结果

搜索发现 GitHub 上不存在名为 "awesome-DRO" 的公开仓库（这说明该领域缺少统一论文索引）。此建议搁置，后续项目直接从论文 PDF 启动。

**值得展示的点**：AI 的预设路径（"先读 awesome-DRO 的 README"）可能失效。此时 AI 应如实报告，而不是强行找替代物填充。

---

## 阶段二：论文定位与选题（约 3 轮）

### 做了什么

刘炜已预先下载论文 PDF：`Gotoh_Kim_Lim_Robustness_Measures_DRO.pdf`。系统用 PyPDF2 提取全文 53 页，逐步阅读。

### 论文理解

- **核心贡献**：将 DRO 的 regularizer 重新解释为"最坏情况敏感度（WCS）"，证明 DRO 本质是性能-鲁棒性权衡，WCS 是广义偏差测度
- **Table 4.1**：给出了五种模糊集（平滑 $\phi$-divergence、Total Variation、Budgeted、凸组合 CVaR、Wasserstein）的显式 WCS 公式
- **两个数值实验**：(1) Inventory control（标量决策，合成数据）；(2) Minimum CVaR portfolio（30 行业组合，真实数据）

### 决策点

刘炜明确指示：只复现实验二（CVaR portfolio），不碰实验一。

**值得展示的点**：面对一篇 53 页的论文，系统采用"渐进式读取"策略——先读摘要/引言建立全局理解，再精读数值实验章节提取参数，最后略读附录。全程不试图一次性读完。

---

## 阶段三：复现方案设计（约 4 轮）

### 技术方案

- **语言选择**：Julia 1.12 + JuMP.jl + Gurobi（理由是 CVaR 含 LP/SOCP 子结构，Gurobi 回调比 MATLAB fmincon 高效；如果只做 inventory 则 MATLAB 也够用，但 CVaR portfolio 需要矩阵操作）
- **数据**：Fama-French 30 Industry Portfolios，从 Kenneth French 网站自动下载
- **模糊集路线**：TV 和 budgeted 用 LP 重构，modified $\chi^2$ 用 SOCP（对偶化为 $\min_{x,\alpha} \text{CVaR}_p + \sqrt{2\varepsilon}\cdot\text{WCS}$）
- **输出**：复现 Figure 5.8（两幅 frontier 图）

### 决策点

刘炜要求先出代码清单再开始写——这是正确的软件工程习惯（design before code）。

系统给出清单后，刘炜追问"数据可以自动下载吗？"系统验证了 Fama-French 的静态 URL（HTTP 200, 312KB），确认可自动化。

**值得展示的点**：方案设计阶段有三个工程判断：(1) 语言选择不是凭喜好，而是基于问题结构（LP/SOCP 的求解器生态）；(2) 数据获取可自动化可手动，优先自动化；(3) 复现范围取舍——三个模糊集全做，但只做 CVaR portfolio，不碰 inventory。

---

## 阶段四：代码实现（约 5 轮）

### 做了什么

一次性写入全部 7 个文件：

| 文件 | 功能 | 行数 |
|------|------|------|
| `Project.toml` | Julia 项目依赖 | ~10 |
| `src/data_loader.jl` | 自动下载并解析 Fama-French CSV | ~60 |
| `src/cvar_utils.jl` | VaR、CVaR、尾部统计量 | ~50 |
| `src/sensitivity_metrics.jl` | Table 4.1⟨ii⟩ 的三种 WCS | ~45 |
| `src/tv_frontier.jl` | TV 模糊集 LP 求解 | ~40 |
| `src/budgeted_frontier.jl` | Budgeted 模糊集 LP 求解 | ~40 |
| `src/chi2_frontier.jl` | Modified $\chi^2$ SOCP 求解 | ~50 |
| `scripts/run_frontiers.jl` | 主驱动脚本 + 绘图 | ~100 |
| `README.md` | 复现说明 | ~30 |

### 故障与修复

**故障 1**：Project.toml 中的包 UUID 是错误的（手工填写导致），Julia Pkg 报 "expected package CSV to be registered"。

**修复**：删除 Project.toml 和 Manifest.toml，用 `Pkg.add()` 让 Julia 自动解析 UUID。教训：不要手工写 UUID，让包管理器自己生成。

**故障 2**：Julia 未安装。

**修复**：`brew install julia`，安装 Julia 1.12.6（与用户需求匹配）。

**故障 3**（未解决）：Gurobi 许可证版本冲突。系统的 Gurobi.jl 自动安装了 Gurobi_jll v13.0.2，但许可证是 v12.0.3。尝试设置 `GUROBI_HOME` 环境变量指向 `/Library/gurobi1203/macos_universal2`，但 JLL 仍优先加载。

**当前状态**：数据加载已验证成功（1196 月 × 30 行业），三个求解器代码未跑通，项目挂起。

**值得展示的点**：真实科研中大约 30-40% 的时间花在环境配置上（"它在我的机器上跑不起来"就是这样的）。尤其是商业求解器（Gurobi）的许可证管理，是工程落地的重要但枯燥的一环。

---

## 阶段六：环境修复与首次成功运行（2026-05-15，约 6 轮）

### 做了什么

定位 Gurobi 许可证冲突的根因：Gurobi.jl 默认走 JLL artifact 拉取 v13 二进制包，忽略本地 v12.0.3 安装。即使 `GRB_LICENSE_FILE` 正确，`deps.jl` 不指向本地库就无法创建 Env。

修复方法：`GUROBI_JL_USE_GUROBI_JLL=false` + `GUROBI_HOME=/Library/gurobi1203/macos_universal2` + `Pkg.build("Gurobi")`，三变量缺一不可。

代码层面的 bug：五个 Julia 模块全部缺少 `export` 语句，`using .Module` 无法引入函数名，导致 `UndefVarError`。补全后一遍跑通。

数值结果：nominal CVaR₀.₉ = 0.0595，S_TV = 0.7488，S_bud = 0.0268。三条 frontier 各 16 个 ε 点共 48 次 Gurobi 调用均求解成功。Budgeted frontier 敏感性下降最显著。

### 经验固化

创建了两个 skill 文件用于后续项目复用：
- `julia-gurobi-debug` — Julia/Gurobi 项目调试清单（许可证 → 库路径 → 模块导出 → 求解器状态）
- `push-github` — 国内网络环境 GitHub 推送链路（web 认证 → HTTPS → SSH 回退）

同时在 `~/.claude/CLAUDE.md` 中记录了 Gurobi 三个必需环境变量。

---

## 阶段七：GitHub 上线（2026-05-15，约 8 轮）

### 做了什么

将项目推送到 https://github.com/WLiu1949/cvar-portfolio-dro。

### 踩坑清单

1. `gh auth login` web 模式被墙 → 手工生成 Personal Access Token，粘贴方式认证
2. Token 缺 `read:org` scope → 编辑补全
3. HTTPS HTTP/2 framing error → 换 HTTP/1.1 仍 empty reply
4. 换 SSH 协议 → 使用已有 ed25519 key，公钥上传 GitHub Settings → 推送成功

### 决策点

这条推送链路在国内网络下是标准操作流程，已固化为 `push-github` skill。

---

## 阶段五：思维链与决策树总结

```
读配置文件 → 发现本地无仓库
    ↓
读论文PDF → 提取两个实验 → 用户选择实验二
    ↓
设计方案 → 用户要求先出代码清单 → 确认自动化下载
    ↓
写代码 → UUID 错误 → Julia未安装 → Gurobi版本冲突
    ↓
挂起，等待下次解决许可证问题
```

---

## 对学生的方法论启示

1. **AI 不是"输入问题、得到答案"**。本次对话约 20 轮，其中 AI 提问/确认约 8 轮。AI 会主动问"数据可以自动下载吗？"这种问题，人的角色是拍板。

2. **先规划，再编码**。代码清单先于代码写入，避免了大量返工。这是软件工程的基本纪律，在 AI 辅助下同样适用。

3. **环境问题不可轻视**。Gurobi 许可证这个小问题让整个项目停在最后一公里。在生产环境中，这类问题应在项目启动前就确认。

4. **AI 会犯错**。UUID 是 AI 手工填的，错了。好的工作流是让工具（Pkg.add）自动生成，而不是让 AI 猜测。

5. **渐进式阅读是好的习惯**。53 页论文，只精读了第 3-5 节和附录 C。其他部分略读。AI 的 Token 节省策略恰好也是研究员的文献阅读策略。

6. **中途搁置也是成果**。代码写完了、数据通了、逻辑验证了，只差一个许可证配置。下次打开项目，5 分钟就能跑通。这是"保存上下文"的价值。
