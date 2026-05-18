# new-api API 网关部署参考（2026-05-16 实测）

## 部署环境
- **系统**：Windows 11 + WSL2（Windows exe 直接运行）
- **存储**：`D:\AI\new api\`
- **端口**：3000（默认）

## 关键发现

### Windows exe 从 WSL 启动的正确方式
WSL 里直接 `./exe` 跑 Windows 程序**可行**，但：
- 用 `background=true` 的 terminal 任务更可靠
- 或者用 PowerShell 中转：`powershell.exe -Command "Start-Process -FilePath '.\new-api.exe'"`

### 端口占用问题
第一次启动如果 3000 端口被占用，会报错：
```
[FATAL] listen tcp :3000: bind: Only one usage of each socket address
```
**解决**：先停旧进程，再启动：
```powershell
Get-Process new-api | Stop-Process -Force
```

### 启动命令
```bash
# WSL 里用 PowerShell 启动（推荐）
cd /mnt/d/AI/new\ api
powershell.exe -Command "cd 'D:\AI\new api'; Start-Process -FilePath '.\new-api.exe' -NoNewWindow -PassThru"

# 或用 subprocess（execute_code 里）
subprocess.Popen(['./new-api.exe'], cwd='/mnt/d/AI/new api', 
                 stdout=open('new-api.log','w'), stderr=subprocess.STDOUT)
```

### 验证启动成功
```bash
# 从 WSL 测试
curl http://localhost:3000  # 返回 200 即成功

# 从 PowerShell 测试
Invoke-WebRequest -Uri 'http://localhost:3000' -UseBasicParsing | Select-Object StatusCode
```

## 启动日志解读
首次启动输出：
```
[SYS] SQL_DSN not set, using SQLite as database    # 使用 SQLite
[SYS] database migration started                   # 初始化数据库
New API v0.0.0  ready in 484 ms
  ➜  Local:   http://localhost:3000/              # 可直接访问
```

**首个注册的账号 = 管理员**，无需邀请码。

## 数据文件
- 数据库：`D:\AI\new api\one-api.db`（SQLite）
- 日志：`D:\AI\new api\logs\` 或当前目录下的 `new-api.log`

## 版本信息
- 最新版本：v1.0.0-rc.6（2026-05-16）
- Windows exe：87MB（直接下载，Linux 下的 tar.gz 需另外下载）
- 下载地址：`https://github.com/Calcium-Ion/new-api/releases/latest`