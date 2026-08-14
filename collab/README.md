# collab — 多 Agent 实时协作中心

同机共享的实时协作基础设施：**消息 / 状态 / 任务 / git 代理** 四通道，供 opencode、DSH（deepseek-harness）、Trae 等 harness 经 **MCP** 接入。纯 Python 标准库，零第三方依赖。

## 快速开始

```powershell
# 1. 启动 relay（消息中心，常驻）
python collab/start_relay.py            # 默认端口 8790，日志 collab/relay.log

# 2. （可选）启动 git 同步/推送代理（解决 DSH 推送阻塞）
python collab/git_sync.py --interval 30

# 3. 在 harness 的 MCP 配置中注册本工具（opencode 已在 opencode.json 注册）
#    "command": ["python", "C:/.../collab/mcp_tools.py"]
```

## 组件

| 文件 | 作用 |
|---|---|
| `relay_server.py` | HTTP 消息中心 + SQLite 持久化（端口 8790） |
| `mcp_tools.py` | MCP stdio 封装，暴露 11 个协作工具 |
| `git_sync.py` | 定时 fetch main + push 代理（消费 push_request 事件代为推送） |
| `start_relay.py` | relay 启动脚本（后台、日志到 relay.log） |
| `test_all.py` | 四通道端到端回归测试 |

## HTTP API（relay_server.py，端口 8790）

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 连通性 |
| POST | `/msg` | 发消息 `{from,to(或ALL),topic,body}` → `{seq}` |
| GET | `/msg?to=&since=` | 拉消息（**长轮询 25s** 准实时） |
| POST | `/status` | 上报状态 `{agent,state,task,role,note}`（心跳 60s 判离线） |
| GET | `/status` | 全部 agent 状态看板 |
| POST | `/task` | 建任务 `{title,detail,assignee}` |
| POST | `/task/claim` | 认领 `{task_id,agent}`（互斥） |
| POST | `/task/done` | 完成 `{task_id,agent,result}` |
| GET | `/task?state=` | 任务列表（open/claimed/done） |
| POST | `/git/push` | 记录 push 代理请求 `{agent,commit}` |
| GET | `/git/push_requests` | 待处理 push 事件（git_sync 轮询） |
| POST | `/git/sync` | 记录同步请求 |

## MCP 工具（11 个）

`post_message / get_messages / report_status / get_status_board / create_task / claim_task / complete_task / get_tasks / git_push_proxy / git_sync / collab_ping`

详细协议见 `skills/git-collab/实时协作协议.md`。

## 测试

```powershell
python collab/test_all.py    # 启动临时 relay -> 四通道自测 -> 自动停止
```

## 说明

- 对话型 harness（opencode/DSH）在**会话中主动调用工具**拉取消息（准实时）；relay 常驻、通道随时可写。
- 7×24 后台自动响应需各 harness 的钩子机制（本次未做）。
- 默认 localhost 无鉴权；跨机部署需加 token。
