-- 设备模型库 schema (Inovance AutoShop 工程代码生成器)
-- 汇川规则固化: R1英文标识符 / 32位占2地址 / 地址唯一 / 类型合法
-- 数据库: SQLite, 文件 db/model.db

PRAGMA foreign_keys = ON;

-- 工程
CREATE TABLE IF NOT EXISTS project (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,          -- 工程名(英文, R1)
    plc_model   TEXT NOT NULL DEFAULT 'H5U',   -- PLC型号
    comm_proto  TEXT NOT NULL DEFAULT 'ModbusTCP', -- 通讯协议
    archetype   TEXT NOT NULL DEFAULT 'host_driven', -- 原型: host_driven / internal_seq
    base_dir    TEXT                            -- 输出目录
);

-- 执行器(伺服/步进/辊筒)
CREATE TABLE IF NOT EXISTS actuator (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id    INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    kind          TEXT NOT NULL CHECK(kind IN ('servo','stepper','roller')), -- 类型
    name_cn       TEXT NOT NULL,               -- 中文名(横移/旋转/夹爪...)
    eng_name      TEXT NOT NULL,               -- 英文名(Cross/Rot/Gripper...)
    idx           INTEGER NOT NULL,            -- 序号 M1/M2/...
    cmd_struct    TEXT,                        -- 命令实体 (servo: M1_Cross_Cmd)
    status_struct TEXT,                        -- 状态实体 (servo: M1_Cross_Status)
    fb_instance   TEXT,                        -- FB实例 (AxisControl_M1_Cross)
    axis_handle   TEXT,                        -- 轴句柄 (servo: Axis_M1_Cross)
    UNIQUE(project_id, kind, idx)
);

-- 通讯寄存器(上位机↔PLC)
CREATE TABLE IF NOT EXISTS comm_reg (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    direction  TEXT NOT NULL CHECK(direction IN ('write','read')), -- 写=命令(上位机→PLC) 读=状态(PLC→上位机)
    var_name   TEXT NOT NULL,                  -- host_Send_Cross_PosNo / host_Rcv_...
    name_cn    TEXT NOT NULL,                  -- 中文名
    data_type  TEXT NOT NULL,                  -- INT/REAL/DINT/BOOL
    d_addr     INTEGER NOT NULL,               -- D 偏移(相对起始, 或绝对 D 号)
    modbus_addr TEXT,                          -- 40001 或 40031-32(32位占2)
    comment    TEXT,
    UNIQUE(project_id, d_addr)                 -- 地址唯一(防重叠)
);

-- 全局变量(io/host/hmi/con)
CREATE TABLE IF NOT EXISTS variable (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id  INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    category    TEXT NOT NULL CHECK(category IN ('io','host','hmi','con','const','inst')),
    var_name    TEXT NOT NULL,
    data_type   TEXT NOT NULL,
    address     TEXT,                          -- X0/Y1/D2000
    comment     TEXT,
    filter_mode TEXT DEFAULT 'builtin' CHECK(filter_mode IN ('none','builtin','debounce')), -- 输入滤波
    filter_ms   INTEGER,                       -- debounce 时滤波时间
    UNIQUE(project_id, category, var_name)
);

-- 结构体
CREATE TABLE IF NOT EXISTS struct_member (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    struct_name TEXT NOT NULL,                 -- AxisControlData / AxisStatusData / ST_MC_Status
    member      TEXT NOT NULL,
    member_type TEXT NOT NULL,
    comment     TEXT,
    UNIQUE(struct_name, member)
);

-- 功能块
CREATE TABLE IF NOT EXISTS fb_param (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    fb_name     TEXT NOT NULL,                 -- FB_Debounce / FB_EtherCAT_Axis_ST
    category    TEXT NOT NULL CHECK(category IN ('IN','OUT','INOUT','VAR')),
    param       TEXT NOT NULL,
    param_type  TEXT NOT NULL,
    comment     TEXT,
    UNIQUE(fb_name, param)
);

-- 程序块(SBR)
CREATE TABLE IF NOT EXISTS sbr_block (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id  INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    sbr_num     INTEGER NOT NULL,              -- 00~08
    sbr_name    TEXT NOT NULL,                 -- sbr_io / sbr_safety / sbr_mode...
    layer       TEXT,                          -- io/safety/mode/manual/auto/axis/main
    archetype   TEXT,                          -- 共用或按原型
    step        INTEGER                        -- STEP 顺序
);

-- 位置表(伺服自动查表)
CREATE TABLE IF NOT EXISTS position_table (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id  INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    axis_idx    INTEGER NOT NULL,              -- M1/M2/...
    pos_no      INTEGER NOT NULL,              -- 位置号 1~5
    position    REAL NOT NULL,                 -- 位置值
    UNIQUE(project_id, axis_idx, pos_no)
);

-- 常量
CREATE TABLE IF NOT EXISTS const_item (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id  INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,                 -- FILTER_TIME_MATERIAL
    data_type   TEXT NOT NULL,                 -- DINT/REAL/INT
    value       TEXT NOT NULL,                 -- 初始值
    comment     TEXT,
    UNIQUE(project_id, name)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_actuator_proj ON actuator(project_id);
CREATE INDEX IF NOT EXISTS idx_comm_proj ON comm_reg(project_id);
CREATE INDEX IF NOT EXISTS idx_var_proj ON variable(project_id);
CREATE INDEX IF NOT EXISTS idx_pos_proj ON position_table(project_id);
CREATE INDEX IF NOT EXISTS idx_const_proj ON const_item(project_id);
