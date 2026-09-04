# -*- coding: utf-8 -*-
"""
collab-relay MCP 工具封装 (stdio transport, JSON-RPC 2.0)
=========================================================
供 opencode / DSH / Trae 等 harness 通过 MCP 接入 collab-relay。
各工具转发到 relay HTTP API (默认 http://127.0.0.1:8790)。

Tools:
  post_message     发送消息 (@定向/广播)
  get_messages     拉取消息 (长轮询准实时)
  report_status    上报状态 (心跳)
  get_status_board 查看所有 agent 状态
  create_task      创建任务 (可指定 role: 生成/审查/测试)
  claim_task       认领任务 (互斥)
  complete_task    完成任务
  review_task      编排器验收任务 (通过归档 / 驳回回 open 重做)
  get_tasks        任务列表
  git_push_proxy   请求 git 推送代理 (解决 DSH 推送阻塞)
  git_sync         请求 git 同步
  collab_ping      连通性检查

启动(接入): 在 harness 的 MCP 配置中注册本脚本:
  python C:/.../collab/mcp_tools.py
"""
import json
import os
import sys
import urllib.request

RELAY = os.environ.get('COLLAB_RELAY', 'http://127.0.0.1:8790')


def _req(method, path, body=None, timeout=30):
    data = json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else None
    r = urllib.request.Request(RELAY + path, data=data, method=method,
                               headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        return json.loads(resp.read().decode('utf-8'))


TOOLS = [
    {
        'name': 'post_message',
        'description': '向指定 agent 或全体(ALL)发送协作消息',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'from': {'type': 'string', 'description': '发送者 agent 名'},
                'to': {'type': 'string', 'description': '接收者 agent 名或 ALL', 'default': 'ALL'},
                'topic': {'type': 'string', 'description': '主题'},
                'body': {'type': 'string', 'description': '消息内容'}
            },
            'required': ['from', 'body']
        }
    },
    {
        'name': 'get_messages',
        'description': '拉取发给自己(或 ALL)的新消息; 返回后请用最新 seq 作为下次 since',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'to': {'type': 'string', 'description': '自己的 agent 名'},
                'since': {'type': 'integer', 'description': '上次最新 seq, 0=全部', 'default': 0}
            },
            'required': ['to']
        }
    },
    {
        'name': 'report_status',
        'description': '上报自己的状态(兼作心跳, 60s 无上报判离线); 状态值: idle/busy/blocked/done',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'agent': {'type': 'string'},
                'state': {'type': 'string', 'enum': ['idle', 'busy', 'blocked', 'done']},
                'task': {'type': 'string', 'description': '当前任务简述'},
                'role': {'type': 'string', 'description': '角色(首次注册)'},
                'note': {'type': 'string'}
            },
            'required': ['agent', 'state']
        }
    },
    {
        'name': 'get_status_board',
        'description': '查看所有已注册 agent 的在线状态看板',
        'inputSchema': {'type': 'object', 'properties': {}}
    },
    {
        'name': 'create_task',
        'description': '创建协作任务',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'title': {'type': 'string'},
                'detail': {'type': 'string'},
                'assignee': {'type': 'string', 'description': '建议执行者 agent 名'},
                'role': {'type': 'string', 'description': '任务角色: 生成/审查/测试, 空=不限'}
            },
            'required': ['title']
        }
    },
    {
        'name': 'claim_task',
        'description': '认领任务(互斥: 已被认领的任务无法再认领)',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'task_id': {'type': 'integer'},
                'agent': {'type': 'string'}
            },
            'required': ['task_id', 'agent']
        }
    },
    {
        'name': 'complete_task',
        'description': '完成任务(须先认领)',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'task_id': {'type': 'integer'},
                'agent': {'type': 'string'},
                'result': {'type': 'string', 'description': '完成说明'}
            },
            'required': ['task_id', 'agent']
        }
    },
    {
        'name': 'review_task',
        'description': '编排器验收已完成任务: approved=true 归档; false 驳回(任务回 open, 附意见供返工)',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'task_id': {'type': 'integer'},
                'agent': {'type': 'string', 'description': '验收者(编排器) agent 名'},
                'approved': {'type': 'boolean'},
                'note': {'type': 'string', 'description': '验收意见/驳回原因'}
            },
            'required': ['task_id', 'agent', 'approved']
        }
    },
    {
        'name': 'get_tasks',
        'description': '任务列表; state 可选 open/claimed/done',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'state': {'type': 'string', 'description': 'open/claimed/done, 缺省全部'}
            }
        }
    },
    {
        'name': 'git_push_proxy',
        'description': '请求 git 推送代理: 提交已就绪时通知 relay, 由 git_sync 代为 push (解决推送通道阻塞)',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'agent': {'type': 'string'},
                'commit': {'type': 'string', 'description': 'commit sha 或分支名'}
            },
            'required': ['agent']
        }
    },
    {
        'name': 'git_sync',
        'description': '请求 git 同步: 触发 fetch main 并广播新提交',
        'inputSchema': {
            'type': 'object',
            'properties': {'agent': {'type': 'string'}},
            'required': ['agent']
        }
    },
    {
        'name': 'collab_ping',
        'description': 'collab-relay 连通性检查',
        'inputSchema': {'type': 'object', 'properties': {}}
    },
]


def _call_tool(name, args):
    a = args or {}
    if name == 'post_message':
        return _req('POST', '/msg', {'from': a.get('from'), 'to': a.get('to', 'ALL'),
                                     'topic': a.get('topic', ''), 'body': a.get('body')})
    if name == 'get_messages':
        return _req('GET', f"/msg?to={a.get('to')}&since={a.get('since', 0)}")
    if name == 'report_status':
        return _req('POST', '/status', {'agent': a.get('agent'), 'state': a.get('state'),
                                        'task': a.get('task', ''), 'role': a.get('role', ''),
                                        'note': a.get('note', '')})
    if name == 'get_status_board':
        return _req('GET', '/status')
    if name == 'create_task':
        return _req('POST', '/task', {'title': a.get('title'), 'detail': a.get('detail', ''),
                                      'assignee': a.get('assignee', ''), 'role': a.get('role', '')})
    if name == 'claim_task':
        return _req('POST', '/task/claim', {'task_id': a.get('task_id'), 'agent': a.get('agent')})
    if name == 'complete_task':
        return _req('POST', '/task/done', {'task_id': a.get('task_id'), 'agent': a.get('agent'),
                                           'result': a.get('result', '')})
    if name == 'review_task':
        return _req('POST', '/task/review', {'task_id': a.get('task_id'),
                                             'agent': a.get('agent'),
                                             'approved': bool(a.get('approved')),
                                             'note': a.get('note', '')})
    if name == 'get_tasks':
        state = a.get('state') or ''
        return _req('GET', '/task' + (f'?state={state}' if state else ''))
    if name == 'git_push_proxy':
        return _req('POST', '/git/push', {'agent': a.get('agent'), 'commit': a.get('commit', '')})
    if name == 'git_sync':
        return _req('POST', '/git/sync', {'agent': a.get('agent')})
    if name == 'collab_ping':
        return _req('GET', '/health')
    raise ValueError(f'unknown tool: {name}')


def _rpc_result(id_, result, is_error=False):
    return {'jsonrpc': '2.0', 'id': id_,
            'result' if not is_error else 'error':
                {'content': [{'type': 'text', 'text': json.dumps(result, ensure_ascii=False)}]}
                if not is_error else {'code': -32000, 'message': str(result)}}


def main():
    server_info = {'name': 'collab-relay-mcp', 'version': '1.0.0'}
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        method = msg.get('method')
        if method == 'initialize':
            out = {'protocolVersion': msg.get('params', {}).get('protocolVersion', '2024-11-05'),
                   'capabilities': {'tools': {}}, 'serverInfo': server_info}
            sys.stdout.write(json.dumps({'jsonrpc': '2.0', 'id': msg.get('id'), 'result': out}) + '\n')
        elif method == 'notifications/initialized':
            continue
        elif method == 'tools/list':
            out = _rpc_result(msg.get('id'), {'tools': TOOLS})
            sys.stdout.write(json.dumps(out, ensure_ascii=False) + '\n')
        elif method == 'tools/call':
            params = msg.get('params', {})
            name = params.get('name')
            args = params.get('arguments') or {}
            try:
                result = _call_tool(name, args)
                out = _rpc_result(msg.get('id'), result)
            except Exception as e:
                out = {'jsonrpc': '2.0', 'id': msg.get('id'),
                       'error': {'code': -32000, 'message': f'{name}: {e}'}}
            sys.stdout.write(json.dumps(out, ensure_ascii=False) + '\n')
        else:
            sys.stdout.write(json.dumps(
                {'jsonrpc': '2.0', 'id': msg.get('id'),
                 'error': {'code': -32601, 'message': f'method not found: {method}'}}) + '\n')
        sys.stdout.flush()


if __name__ == '__main__':
    main()
