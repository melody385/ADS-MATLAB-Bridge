# ADS-MATLAB-Bridge

一个用于连接 **MATLAB** 与 **Keysight ADS** 的自动化仿真与优化工具。

如果你平时反复被这些事情困扰：

- 在 ADS 中花费大量时间 tuning
- 重新仿真效果始终不佳
- 无法同时兼顾不同目标
- 想试试 ADS 自带的优化却一直报错
- 心累

那么不妨看看这个项目：

> 把这些重复操作交给程序，让 MATLAB 可以直接调用 ADS、读取结果，并进一步完成自动优化。

目前项目已经完成 **S 参数（SP）自动化工作流**，可用于滤波器、匹配网络以及其他以 S11 / S21 为主要评价指标的电路。

后续将继续扩展 PA / Harmonic Balance 等模块。

---

## 项目结构

```text
ADS-MATLAB-Bridge/
│
├─ README.md
├─ doctor_ads.m
├─ doctor_workspace.m
├─ doctor_simulator.m
│
├─ core/
│  └─ MATLAB ↔ ADS 公共桥接核心
│
└─ sp/
   ├─ S 参数用户入口
   └─ internal/
      └─ S 参数后台模块
```

正常使用时，你主要需要接触：

```text
doctor_ads.m
doctor_workspace.m
doctor_simulator.m

sp/sp_baseline.m
sp/sp_targets.m
sp/sp_constraints.m
sp/sp_check.m
sp/sp_optimizer.m
```

程序还会根据你的 ADS 网表自动生成：

```text
sp_variables.m
```

---

# 开始之前

你需要准备：

- MATLAB
- Keysight ADS
- 一个能够在 ADS 中正常仿真的工程
- ADS 已正确加载工程所需模型库 / Design Kit
- ADS License 工作正常
- 一份由 ADS 生成的可用网表（放在工程文件夹里）

建议先在 ADS 中手动运行一次原始设计。

如果原始设计本身无法在 ADS 中正常仿真，Bridge 不会尝试替你修复电路。

这个项目负责的是：

```text
一个已经能正常工作的 ADS 设计
↓
进入 MATLAB 自动仿真与优化流程
```

---

# 快速开始

第一次使用时，按下面顺序运行即可。

## 1. 检查 ADS

运行：

`doctor_ads.m`

它会寻找当前电脑中的 ADS 安装，并定位 `hpeesofsim.exe`。

如果电脑中存在多个 ADS 版本，程序会让你选择要使用的版本。

成功后会看到类似：

```text
STEP 1 PASSED
```

---

## 2. 选择 ADS Workspace

运行：

`doctor_workspace.m`

程序会弹出文件夹选择窗口。

选择你准备进行自动仿真的 ADS Workspace。

程序会检查常见 Workspace 配置、`lib.defs`、本地 Library 与外部模型库引用。

它不会修改你的 Workspace。

成功后会看到类似：

```text
STEP 2 PASSED
```

---

## 3. 检查 ADS Simulator

运行：

`doctor_simulator.m`

这一步负责让当前 MATLAB 会话能够正确启动 ADS 命令行仿真器。

程序会配置当前会话需要的 ADS Runtime 环境，并测试 `hpeesofsim` 是否能够正常启动。

不会永久修改 Windows 环境变量，也不会永久修改 MATLAB Path。

成功后会看到类似：

```text
STEP 3 PASSED
```

---

# S 参数自动优化

前三步通过后，就可以进入 `sp` 文件夹。

当前 SP 模块适用于：

- 低通滤波器
- 高通滤波器
- 带通滤波器
- 带阻滤波器
- 匹配网络
- 其他以 S11 / S21 为主要评价指标的电路

你可以自由定义任意频带内的：

- S11 最小值
- S11 最大值
- S21 最小值
- S21 最大值

也可以单独设置特殊频点的 S11 / S21 要求。

---

# 第一步：跑一次 Baseline

运行：

`sp/sp_baseline.m`

程序会自动完成相关解析。

成功运行后，你会看到 MATLAB 绘制出与 ADS 仿真结果对应的 S 参数曲线。

到这里，说明 **MATLAB → ADS → RAW → MATLAB** 这条基础链路已经跑通。

不用担心：

> 原始 ADS 正式网表不会被修改。

所有自动参数修改和仿真都发生在 Bridge 创建的临时 CASE 中。

Baseline 成功后，程序会自动生成：

`sp_variables.m`

保存到：

```text
<你的工程>\ADS_MATLAB_BRIDGE_Run\Config\sp_variables.m
```

并自动在 MATLAB 中打开它。

所以你不需要自己去文件夹里找变量配置。

---

# 第二步：设置优化变量

自动生成的 `sp_variables.m` 会类似这样：

```matlab
% Name       Initial    Lower    Upper    Step     Enable

"W1"         , 0.60,     0.30,    0.90,    0.06,   true;
"W2"         , 0.60,     0.30,    0.90,    0.06,   true;
"L1"         , 3.10,     1.55,    4.65,    0.31,   true;
```

程序默认给出：

```text
Lower = Initial - 50%
Upper = Initial + 50%
Step  = |Initial| × 10%
```

这些只是初始建议，不是强制规则。

你应该根据自己的实际结构修改。

如果某个变量暂时不希望优化：

```matlab
Enable = false
```

即可固定它。

你真正控制的是：

```text
优化哪些参数？
每个参数从哪里搜到哪里？
每一步多大？
哪些参数固定？
```

---

# 第三步：设置 S 参数目标

打开：

`sp/sp_targets.m`

例如：

```matlab
TARGET.bands = cell2table({
    "Band_1",  1.0,  3.0,  NaN, -15, -0.3, NaN;
    "Band_2",  4.0, 10.0,   -3, NaN,  NaN, -22;
}, 'VariableNames', {
    'Name', 'Fstart_GHz', 'Fstop_GHz',
    'S11_Min_dB', 'S11_Max_dB',
    'S21_Min_dB', 'S21_Max_dB'
});
```

每一行代表一个频带。

不需要的一侧写：

```matlab
NaN
```

例如：`S11 <= -15 dB`

对应：

```text
S11_Min = NaN
S11_Max = -15
```

例如：`S21 >= -0.3 dB`

对应：

```text
S21_Min = -0.3
S21_Max = NaN
```

每一行代表一个独立频带目标；如果只有一个频带，只保留一行即可，需要更多频带时继续向下添加新行。

## 特殊频点

除了整段频带，还可以单独要求某个频点。

例如：

```text
3.10 GHz 时 S21 <= -3 dB
```

可以写成：

```matlab
TARGET.special = cell2table({
    "S21", 3.10, NaN, -3;
}, 'VariableNames', {
    'Parameter', 'Frequency_GHz', 'Min_dB', 'Max_dB'
});
```

这个功能适合控制截止位置、滚降速度、局部抑制度和特殊频点匹配。

---

# 第四步：按需添加参数关系约束

打开：

`sp/sp_constraints.m`

如果你的结构存在不能只靠单个变量上下限表达的关系，可以写在这里。

例如：

```text
L3 < L1
```

或者：

```text
W1 + W2 + L1/2 <= 6.5
```

示例：

```matlab
CONSTRAINTS = cell2table({
    "Length_Order", "L3", "<", "L1", true;
    "Clearance", "W1 + W2 + L1/2", "<=", "6.5", true;
}, 'VariableNames', {
    'Name',
    'LeftExpression',
    'Operator',
    'RightExpression',
    'Enable'
});
```

如果当前工程没有特殊约束，保持：

```matlab
Enable = false
```

即可。

每一行代表一条独立约束；有多条尺寸关系时继续向下添加即可。第一列 `Name` 只是约束名称，用于识别和结果提示，不参与计算。

这些约束会在 ADS 仿真之前检查。

如果某组参数已经违反约束：

```text
候选参数
↓
Constraint Check
↓
REJECTED
```

这组参数不会再浪费一次 ADS 仿真。

---

# 第五步：确认 MATLAB 真的改动了 ADS

正式开始大量优化之前，建议先运行：

`sp/sp_check.m`

它会自动完成：

```text
读取 sp_variables
↓
选择一个可优化变量
↓
改变一个 Step
↓
写入临时 CASE
↓
调用 ADS
↓
读取新的 RAW
↓
比较 S11 / S21
```

如果整个参数接口链路正确，会看到：

```text
SP PARAMETER INTERFACE TEST PASSED
```

这意味着：

> MATLAB 修改的参数真的进入了 ADS，新 ADS 仿真结果也真的重新回到了 MATLAB。

---

# 第六步：开始优化

确认变量、目标和约束后，运行：

`sp/sp_optimizer.m`

测试阶段建议先使用较小规模，例如：

```matlab
OPT.swarmSize = 4;
OPT.maxIterations = 2;
```

确认流程正常以后，再根据问题规模增加粒子数和迭代次数。

优化过程大致为：

```text
PSO 产生候选参数
↓
按用户设置的 Step 离散
↓
检查特殊参数约束
↓
写入临时 CASE
↓
ADS 仿真
↓
RAW
↓
S11 / S21
↓
评价全部目标
↓
更新粒子
↓
寻找更好的参数
```

违反特殊约束的候选会直接显示：

```text
CONSTRAINT REJECTED
```

并跳过 ADS 仿真。

---

# 优化结果

Bridge 不只是判断 PASS / FAIL。

对于没有满足的目标，它会计算距离目标还差多少，并形成统一的 violation / objective。

如果最终所有目标都满足，会显示：

```text
ALL TARGETS PASSED : YES
```

否则程序仍会保存当前找到的最佳方案。

结果通常保存在：

```text
<ADS_WORKSPACE>\ADS_MATLAB_BRIDGE_Run\
```

SP 优化通常会生成：

```text
best_parameters.csv
best_sparameters.csv
best_target_details.csv
best_result.mat
best_case.log
best.raw
optimization_history.csv
SP_OPTIMIZATION_RESULT.mat
```

---

# 一次完整的使用顺序

如果你只想知道“我应该按什么顺序做”，看这里即可：

```text
doctor_ads
↓
doctor_workspace
↓
doctor_simulator
↓
sp/sp_baseline
↓
修改自动打开的 sp_variables.m
↓
修改 sp/sp_targets.m
↓
按需修改 sp/sp_constraints.m
↓
sp/sp_check
↓
sp/sp_optimizer
```

第一次建议：

```text
Baseline 正常
↓
Parameter Interface Test Passed
↓
小规模优化正常
↓
再开始正式搜索
```

---

# 这个项目不会替你做什么？

ADS-MATLAB-Bridge 不是一个“一键自动设计任意射频电路”的黑箱。

它不会替代：

- ADS 原理图设计
- 电磁结构设计
- 合理的参数选择
- 工程约束判断
- 模型库配置
- 射频设计经验

它解决的是另一个问题：

> 当你已经有一个可以工作的 ADS 设计以后，怎样把大量重复的“改参数 → 仿真 → 读结果 → 判断 → 再修改”自动化。

工程师负责决定：

```text
优化哪些参数
参数允许怎样变化
性能目标是什么
有哪些物理/几何约束
```

ADS-MATLAB-Bridge 负责反复执行这些规则。

---

# 为什么有 core/、sp/ 和 internal/？

`core/` 负责 MATLAB 和 ADS 之间的公共能力，例如：

```text
ADS 调用
临时 CASE
RAW 解析
参数写入
Baseline
```

`sp/` 负责 S 参数应用。

`sp/internal/` 是后台模块，正常用户不需要手动运行。

这样做是为了后续继续增加其他模块，例如：

```text
pa/
```

用于功率放大器 / Harmonic Balance 自动化，而不需要重新复制一套 ADS Bridge。

未来项目希望形成：

```text
ADS-MATLAB-Bridge/
│
├─ core/
├─ sp/
└─ pa/
```

用户只需要下载一次项目，再根据自己的任务进入对应模块。

---

# 常见问题

## doctor_simulator 通过，但正式仿真仍然失败？

`doctor_simulator` 主要确认 ADS Simulator 可以从当前 MATLAB 环境启动。

真正执行 SP / HB 仿真时仍然需要对应的 ADS License。

建议先确认 ADS GUI 中原设计可以正常手动仿真。

## 为什么目标频率超出 ADS 扫频范围会直接报错？

例如 ADS 实际只仿真：

```text
1 ~ 10 GHz
```

但你要求：

```text
0.5 ~ 3 GHz
```

程序不会偷偷裁成 `1 ~ 3 GHz`，而是直接停止。

这样可以避免用户误以为未仿真的频段已经完成评价。

## 为什么不直接修改原始网表？

为了安全。

Bridge 尽量保持：

```text
正式网表 = 只读输入
```

每次测试和优化使用临时 CASE，因此优化失败也不会修改原始 ADS 正式网表。

## 模型库需要上传到 GitHub 吗？

不需要，也不建议。

商业模型、Design Kit、厂商器件库应继续由用户自己的 ADS Workspace 和本机环境管理。

---

# 当前状态

目前已经完成：

```text
ADS 自动检测
Workspace / Library 检查
Simulator Runtime 配置
命令行 ADS 仿真
临时 CASE
Nutmeg RAW 解析
S11 / S21 Baseline
优化变量自动生成
参数写入接口检查
任意频带 S11 / S21 目标
特殊频点目标
参数关系约束
Pre-ADS 约束筛选
PSO 自动优化
Best / History 保存
```

后续计划继续扩展：

```text
PA / Harmonic Balance 自动化
PA 指标计算
Pout / Gain / DE 等目标
PA 参数优化
```

---

# 第一次使用，从这里开始

如果你第一次打开这个项目，不需要先读完所有源码。

先依次运行：

```text
doctor_ads.m
doctor_workspace.m
doctor_simulator.m
```

三个都通过以后，进入：

```text
sp/
```

从：

```text
sp_baseline.m
```

开始。

如果最终能看到：

```text
SP PARAMETER INTERFACE TEST PASSED
```

以及：

```text
SP OPTIMIZATION FINISHED
```

那么 MATLAB ↔ ADS 的自动优化闭环已经建立完成。
