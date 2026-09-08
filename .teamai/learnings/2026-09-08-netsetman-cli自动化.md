# NetSetMan CLI 自动化要点 (ETW600 网桥流程实测)

- CLI 语法: netsetman.exe -as "方案名" (激活并自动关窗); -a 激活; -h 托盘启动; 支持 -a 方案1,方案2 多开
- 确认框卡点: 默认 Preferences/Confirmation activation=True 时, CLI 激活只弹确认框不执行, 自动化被卡
  -> 改 False 后完全无人值守 (已固化, 备份 netsetman.xml.bak2-20260908)
- 配置直改: netsetman.xml 可程序化增删方案 (ElementTree), 但须先退出运行实例(管理员权限 taskkill 杀不掉,
  需人工托盘退出), 否则内存态可能覆盖
- 127.0.0.1 是环回保留地址, 不能绑定物理网卡 (netsh/NetSetMan 均拒绝) —— 测试占位 IP 请用真实网段
- 双 IP 技巧: 一个网卡可同时挂 169.254.0.10/16(设备配置口) + 192.168.1.x/24(PLC 网), 配外设不断内网
- 管理员权限运行的程序, 非 admin 的 AI 进程无法 UIPI 自动化点击 —— 要么关确认框, 要么人工点
