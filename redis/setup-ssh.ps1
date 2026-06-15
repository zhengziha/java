# SSH免密登录配置脚本
# 为3台虚拟机配置SSH免密登录

# 服务器信息
$NODE1_IP = "192.168.56.106"
$NODE2_IP = "192.168.56.107"
$NODE3_IP = "192.168.56.108"
$SSH_USER = "root"
$SSH_PASSWORD = "root"

$NODES = @($NODE1_IP, $NODE2_IP, $NODE3_IP)

Write-Host "========================================" -ForegroundColor Green
Write-Host "配置SSH免密登录" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 检查SSH密钥是否存在
$sshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
$sshPubKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"

if (-not (Test-Path $sshKeyPath)) {
    Write-Host "步骤1: 生成SSH密钥对..." -ForegroundColor Yellow
    ssh-keygen -t rsa -b 4096 -f $sshKeyPath -N '""' 2>&1 | Out-Null
    Write-Host "✓ SSH密钥对已生成" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "步骤1: SSH密钥已存在" -ForegroundColor Green
    Write-Host ""
}

# 获取公钥内容
$publicKey = Get-Content $sshPubKeyPath -Raw

# 为每个节点配置免密登录
foreach ($node in $NODES) {
    Write-Host "步骤2: 配置节点 $node 的免密登录..." -ForegroundColor Yellow
    
    # 使用sshpass自动输入密码（如果可用）
    $useSshpass = $false
    try {
        $null = Get-Command sshpass -ErrorAction Stop
        $useSshpass = $true
    }
    catch {
        Write-Host "  未找到sshpass工具，将使用手动密码输入" -ForegroundColor Yellow
    }
    
    if ($useSshpass) {
        # 使用sshpass自动复制公钥
        sshpass -p $SSH_PASSWORD ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$node" 2>&1 | Out-Null
    }
    else {
        # 手动方式：先创建.ssh目录，然后追加公钥
        $createDirCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        $appendKeyCmd = "echo '$publicKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        
        # 使用expect或其他方式自动输入密码
        # 这里我们使用PowerShell的SSH方式
        try {
            # 尝试连接并执行命令（可能需要手动输入密码）
            Write-Host "  正在连接到 $node (可能需要输入密码)..." -ForegroundColor Cyan
            
            # 创建临时脚本
            $tempScript = @"
$createDirCmd
$appendKeyCmd
"@
            $tempScript | Out-File -FilePath "temp_setup.sh" -Encoding ASCII
            
            # 尝试使用scp传输脚本
            scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "temp_setup.sh" "${SSH_USER}@${node}:/tmp/temp_setup.sh" 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                # 执行脚本
                ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${node}" "bash /tmp/temp_setup.sh" 2>&1 | Out-Null
                Write-Host "  ✓ 公钥已复制到 $node" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠ 自动配置失败，请手动执行以下命令：" -ForegroundColor Yellow
                Write-Host "    ssh-copy-id ${SSH_USER}@${node}" -ForegroundColor Cyan
            }
            
            # 清理临时文件
            Remove-Item "temp_setup.sh" -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "  ⚠ 自动配置失败，请手动执行以下命令：" -ForegroundColor Yellow
            Write-Host "    ssh-copy-id ${SSH_USER}@${node}" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
}

# 测试免密登录
Write-Host "步骤3: 测试免密登录..." -ForegroundColor Yellow
$allSuccess = $true

foreach ($node in $NODES) {
    Write-Host "  测试 ${node}: " -NoNewline
    
    try {
        $result = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "${SSH_USER}@${node}" "echo 'success'" 2>&1
        
        if ($result -match "success") {
            Write-Host "✓ 成功" -ForegroundColor Green
        }
        else {
            Write-Host "✗ 失败" -ForegroundColor Red
            $allSuccess = $false
        }
    }
    catch {
        Write-Host "✗ 失败" -ForegroundColor Red
        $allSuccess = $false
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
if ($allSuccess) {
    Write-Host "SSH免密登录配置完成！" -ForegroundColor Green
}
else {
    Write-Host "部分节点配置失败，请手动配置" -ForegroundColor Yellow
    Write-Host "手动配置命令：" -ForegroundColor Cyan
    foreach ($node in $NODES) {
        Write-Host "  ssh-copy-id ${SSH_USER}@${node}" -ForegroundColor Cyan
    }
}
Write-Host "========================================" -ForegroundColor Green