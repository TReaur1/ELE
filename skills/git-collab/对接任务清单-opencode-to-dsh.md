# DSH 对接任务清单（opencode → deepseek-harness）

> 背景：GitHub HTTPS 443 对本机间歇性阻断（读/写均不稳定），SSH 443（ssh.github.com）实测稳定可连。
> opencode 已生成 SSH 密钥并配置 `~/.ssh/config`，**唯一需要人工/GitHub 网页的操作是第 1 项**，其余 DSH 可在本机完成。
> 对接完成后，DSH 具备：稳定推送通道 + collab-relay 实时协作 + 后台常驻响应。

---

## 任务 1：添加 SSH 公钥到 GitHub（需网页操作）
- **公钥**（复制全部）：
  ```
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAVs+PPacRl+8M7LA93JOpimTJO7CzeTjrXMVfM+iLbG kaanh-ELE-collab
  ```
- **位置**：GitHub → Settings → **SSH and GPG keys** → New SSH key → Title `ELE-collab` → 粘贴 → Add。
- **验证**：`ssh -T git@github.com` 应显示 `Hi kaanh! You've successfully authenticated`。

## 任务 2：仓库 remote 切换为 SSH
- 命令：`cd C:\Users\kaanh\Documents\Default Project`
  `git remote set-url origin git@github.com:TReaur1/ELE.git`
- 验证：`git ls-remote origin main` 返回 sha 即通。

## 任务 3：推送待推送提交
- 当前有 1 笔本地提交未推送：`fb5f50b`（agent_daemon 后台常驻响应 + DSH HARNESS 更新）。
- 命令：`git push origin main`。
- 若再偶发失败：重试 1~2 次（间歇性网络）；或临时切回 HTTPS `git remote set-url origin https://github.com/TReaur1/ELE.git` 再试。

## 任务 4：启动实时协作基础设施（常驻）
- 启动 relay：`python C:\Users\kaanh\Documents\Default Project\collab\start_relay.py`
- 启动后台守护（notify 模式，安全默认）：
  `python C:\Users\kaanh\Documents\Default Project\collab\agent_daemon.py --mode notify --agent deepseek-harness --inbox C:\Users\kaanh\Documents\Default Project\collab\inbox_dsh.md`
- 验证：`curl http://127.0.0.1:8790/health` 返回 `{"ok": true, ...}`。

## 任务 5：DSH 接入 collab-relay MCP
- 在 DSH 的 MCP 配置中注册（与 opencode.json 同构）：
  ```json
  "collab-relay": {
    "type": "local",
    "command": ["python", "C:/Users/kaanh/Documents/Default Project/collab/mcp_tools.py"],
    "environment": { "COLLAB_RELAY": "http://127.0.0.1:8790" },
    "enabled": true
  }
  ```
- 验证：会话中调用 `collab_ping` 返回 `ok: true`。

## 任务 6：DSH 协作自测（会话内）
1. `report_status(agent=deepseek-harness, state=idle, role=电气)` —— 看板注册。
2. `get_messages(to=deepseek-harness, since=0)` —— 补拉历史消息。
3. `post_message(from=deepseek-harness, to=ALL, topic=状态, body=DSH 已接入实时协作)`。
4. 认领 opencode 或人工建的任务：`get_tasks(state=open)` → `claim_task` → 执行 → `complete_task`。
5. 会话结束时 `report_status(state=idle, note=...)`（60s 无心跳自动离线）。

## 任务 7（可选进阶）：auto 自动执行任务
- `agent_daemon.py --mode auto`（当前已用 notify，人工确认更稳；auto 会真实调用 opencode run 消耗 API）。

---

## 交付确认（完成后在 CHANGELOG.md 追加条目）
- 格式：`[v0.2.0] 2026-08-14 — DSH 完成 SSH 通道对接 + collab-relay 接入 + 后台守护运行`
- 涉及仓库改动走 `feature/deepseek-harness/<简述>` 分支 + PR，CI 通过后合并。
