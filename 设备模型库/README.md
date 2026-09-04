# 设备模型库 — 汇川 AutoShop 工程代码生成器 使用说明

从一份 JSON 设备规格单一键生成汇川工程的**变量表 / FB 表 / 结构体表 / 通讯字表(XLSX) / 完整 ST 逻辑(SBR_00~08)**。

## 环境要求
- Python 3.x（已确认可用）
- 依赖：`openpyxl`、`jinja2`（已装）
- 表生成输出为 **GBK+CRLF**（AutoShop 导入兼容）

## 目录结构
```
设备模型库\
├── db\schema.sql           SQLite 表结构 + 约束(R1/地址唯一/32位占2/CASCADE)
├── db\model.db             生成的模型库(多工程共存)
├── spec\*.json             设备规格单(每个工程一份)
├── scripts\
│   ├── load_spec.py        规格单→SQLite(含校验)
│   ├── generate_tables.py  表生成(变量/FB/结构体/通讯字表/con/inst/hmi)
│   ├── generate_st.py      ST生成(SBR_00~08, Jinja2, 按原型路由)
│   ├── shared_data.py      共享数据(结构体/FB/con变量/原型扩展)
│   ├── sync_cloudbrain.py  图谱派生清单
│   └── verify_*.py         校验脚本
├── templates\
│   ├── common\             通用模板(SBR_00~08)
│   └── archetype\
│       ├── host_driven\    上位机驱动型(位置查表, 全自动)
│       └── internal_seq\   内部流程型(步状态机框架, 工步人工填)
└── output\{project}\       每工程独立输出(28 文件)
```

## 快速上手（三步）
```bash
cd 设备模型库

# 1) 规格单 → SQLite（含 32位占2地址/地址唯一/R1 校验，拦截重叠错误）
python scripts\load_spec.py spec\virtual_project.json

# 2) 生成表格（变量表 + 通讯字表XLSX + 结构体/FB/con/inst/hmi 表）
python scripts\generate_tables.py virtual_project

# 3) 生成 ST（SBR_00~08）
python scripts\generate_st.py virtual_project
```
输出到 `output\virtual_project\`。

## 一键生成 + 自动审查（推荐）
```bash
python scripts\generate.py <工程名>
```
等价于 ①加载规格单 → ②生成表格 → ③生成ST → **④审查ST**。审查发现未声明符号 / R1 违规会返回非 0 退出码，**每次生成后自动审查**。

## 代码审查（review_st）
```bash
python scripts\review_st.py <工程名>   # 审查: 未声明符号 / R1中文标识符 / R2零声明 / 魔法数字
```
规则（**自动推断, 不依赖手工白名单**）：
- **未声明符号**：ST 用到的变量/实例/常量/类型须在表中声明
- **自动豁免**（由上下文推断，非手列）：
  - X/Y 物理地址（`^[XY]\d+$`）
  - `sbr_*` 子程序名
  - 结构体成员（`.` 右侧）
  - **FB 调用参数**（括号内 `:=`/`=>` 左侧，如 MC_*、FB 接口参数）——不再手工维护参数白名单
  - FB 内部局部变量（从 FB VAR 块提取）
- **R1**：注释外禁止中文字符；**R2**：程序块禁止 VAR 声明
- **软警告**：魔法数字

## 新建工程流程
1. **复制规格单**：`cp spec\virtual_project.json spec\my_project.json`（或手写）
2. **改工程信息**：`project.name`、`project.archetype`（`host_driven` / `internal_seq`）、`project.plc_model`、`project.comm_proto`
3. **填设备**：
   - `actuators`：伺服(kind=servo, 需 cmd_struct/status_struct/fb_instance/axis_handle)、步进(stepper)、辊筒(roller)
   - `comm_write` / `comm_read`：上位机通讯寄存器（**手填 `d_addr`**，REAL/DINT 占 2 地址需留空位，生成器会校验重叠）
   - `io`：物理 X/Y，输入可标 `filter_mode`（none=急停不滤波 / builtin=内置滤波 / debounce=额外消抖）
   - `position_tables`：每轴位置号 1~n 的查表值（host_driven 用）
   - `constants`：常量（超时/速度/滤波/故障码）
4. 跑上面的三步命令，工程名换成 `my_project`

## 两个原型（archetype）
| 原型 | 说明 | SBR_06 |
|---|---|---|
| `host_driven` | 上位机全命令驱动（位置号+启动） | 全自动生成（位置查表 CASE） |
| `internal_seq` | PLC 内部自动流程 | 生成**步状态机框架**（步号+CASE+门控），非标准工步体由工程师在生成的 `.st` 里人工填写 |

`internal_seq` 会自动追加步框架变量（con_Step_*、host_Send_Start/Stop/Home、r_StepFwd 等）到表。

## 关键规则（已固化）
- **R1 标识符**仅英文（生成器校验）
- **32 位(REAL/DINT)占 2 地址**：通讯表自动按 2 递增，重叠会报错
- **地址手填 + 校验**：唯一性/类型
- **通讯字表 XLSX**：同示例样式（华文楷体表头蓝底、楷体段标黄/绿、等线数据、换行美化）
- **GBK+CRLF** 输出

## 知识图谱（可选）
```bash
python scripts\sync_cloudbrain.py virtual_project   # 打印待写入实体/关系清单
```
由 AI 据清单调用 cloud_brain MCP 工具写入图谱（图由表派生）。

## 校验脚本
```bash
python scripts\verify_counts.py        # 检查工程/comm_reg 数量、host 表行数、防翻倍
python scripts\verify_consistency.py   # 检查 ST 引用变量是否都在表里声明
```

## 扩展
- 新增共享 FB/结构体/con 变量 → 编辑 `scripts\shared_data.py`
- 新增原型 → `templates\archetype\<name>\` 放 SBR_04/05/06 模板 + `shared_data.py` 的 `ARCHETYPE_EXTRA` 加变量
- 修改模板 → `templates\common\*.j2` 或 `templates\archetype\*\*.j2`


## 系统级网络安全建议（无线上位机链路, 2026-09-04）

PLC 侧已实现失联安全（三级看门狗 → RunOK 联锁），但无线段本身建议同步加固：

- **AP 侧**：MAC 白名单 / WPA2-Enterprise；上位机与 PLC 划独立 VLAN，与办公网隔离。
- **协议**：Modbus TCP 为明文无鉴权，禁止跨网段暴露 502 端口；跨网段时经工业网关/VPN。
- **上位机**：命令下发前先校验 `host_Rcv_CommState`（降级/断讯时置灰命令）；以回执/实际状态为执行依据（细则16）。
