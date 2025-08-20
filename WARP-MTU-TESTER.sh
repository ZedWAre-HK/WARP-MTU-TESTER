#!/bin/bash

cat << "EOF"
 _____             __ _       __ ___                                                                    
/__  /  ___   ____/ /| |     / //   |   _____ ___                                                       
  / /  / _ \ / __  / | | /| / // /| |  / ___// _ \                                                      
 / /__/  __// /_/ /  | |/ |/ // ___ | / /   /  __/                                                      
/____/\___/ \__,_/   |__/|__//_/  |_|/_/    \___/                                                       
    _   __       __                          __                                                         
   / | / /___   / /_ _      __ ____   _____ / /__                                                       
  /  |/ // _ \ / __/| | /| / // __ \ / ___// //_/                                                       
 / /|  //  __// /_  | |/ |/ // /_/ // /   / ,<                                                          
/_/ |_/ \___/ \__/  |__/|__/ \____//_/   /_/|_|                                                         
    ___     __    __   _                                        __ __             __            ____ __ 
   /   |   / /__ / /_ (_)___   ____   ____ _ ___   _____ ___   / // /_____ _____ / /_   ____ _ / __// /_
  / /| |  / //_// __// // _ \ / __ \ / __ `// _ \ / ___// _ \ / // // ___// ___// __ \ / __ `// /_ / __/
 / ___ | / ,<  / /_ / //  __// / / // /_/ //  __/(__  )/  __// // /(__  )/ /__ / / / // /_/ // __// /_  
/_/  |_|/_/|_| \__//_/ \___//_/ /_/ \__, / \___//____/ \___//_//_//____/ \___//_/ /_/ \__,_//_/   \__/  
                                   /____/                                                               

EOF

HEADERS_IPV4=20
HEADERS_IPV6=48
WG_OVERHEAD=80
TRIES=20

PASS_RATES=(100 90 80)
COLORS=("\e[32m" "\e[33m" "\e[31m")
NC="\e[0m"

USE_TOOL=""
if command -v nslookup >/dev/null 2>&1 && command -v dig >/dev/null 2>&1; then
    echo "[*] 检测到 nslookup 和 dig，将优先使用 nslookup 解析"
    USE_TOOL="nslookup"
elif command -v nslookup >/dev/null 2>&1; then
    echo "[*] 检测到 nslookup，将使用 nslookup 解析"
    USE_TOOL="nslookup"
elif command -v dig >/dev/null 2>&1; then
    echo "[*] 检测到 dig，将使用 dig 解析"
    USE_TOOL="dig"
else
    echo "[-] 请先安装 nslookup 或 dig"
    exit 1
fi

read -p "请选择测试 IP 类型 [4/6] 默认6: " IP_VER
IP_VER=${IP_VER:-6}
if [[ "$IP_VER" != "4" && "$IP_VER" != "6" ]]; then
    echo "[-] 输入无效，退出"
    exit 1
fi

TARGET_DOMAIN="engage.cloudflareclient.com"
echo "[*] 正在解析 $TARGET_DOMAIN ..."
if [ "$USE_TOOL" == "nslookup" ]; then
    if [ "$IP_VER" == "4" ]; then
        TARGET_IP=$(nslookup $TARGET_DOMAIN | awk '/^Address: / {print $2}' | head -n1)
    else
        TARGET_IP=$(nslookup -type=AAAA $TARGET_DOMAIN | awk '/^Address: / {print $2}' | head -n1)
    fi
else
    if [ "$IP_VER" == "4" ]; then
        TARGET_IP=$(dig +short A @$1.1.1.1 $TARGET_DOMAIN | head -n1)
    else
        TARGET_IP=$(dig +short AAAA @1.1.1.1 $TARGET_DOMAIN | head -n1)
    fi
fi

if [ -z "$TARGET_IP" ]; then
    echo "[-] 解析失败"
    exit 1
fi
echo "[+] 解析结果: $TARGET_IP"

if [ "$IP_VER" == "4" ]; then
    HEADERS=$HEADERS_IPV4
else
    HEADERS=$HEADERS_IPV6
fi

echo "[*] 开始 MTU 测试，每个 MTU 尝试 $TRIES 次"

check_mtu() {
    local mtu=$1
    local rate_threshold=$2
    local size=$((mtu - HEADERS))
    local success=0
    for ((i=1;i<=TRIES;i++)); do
        if ping${IP_VER} -c1 -W1 -M do -s $size $TARGET_IP >/dev/null 2>&1; then
            success=$((success+1))
        fi
        printf "\r  -> 测试 MTU=%d (payload=%d) [%d/%d 成功]" "$mtu" "$size" "$success" "$i"
    done
    echo ""
    local rate=$((success*100/TRIES))
    if [ $rate -ge $rate_threshold ]; then
        return 0
    else
        return 1
    fi
}

declare -A best_mtu
for idx in "${!PASS_RATES[@]}"; do
    rate=${PASS_RATES[$idx]}
    color=${COLORS[$idx]}
    low=1200
    high=1500
    best=1280
    while [ $low -le $high ]; do
        mid=$(((low+high)/2))
        if check_mtu $mid $rate; then
            best=$mid
            low=$((mid+1))
        else
            high=$((mid-1))
        fi
    done
    best_mtu[$rate]=$best
done

echo -e "\n[+] 检测完成：最大 MTU"
displayed=()
for idx in "${!PASS_RATES[@]}"; do
    rate=${PASS_RATES[$idx]}
    color=${COLORS[$idx]}
    mtu=${best_mtu[$rate]}
    warp_mtu=$((mtu - WG_OVERHEAD))
    if [[ " ${displayed[*]} " =~ " $mtu " ]]; then
        continue
    fi
    same_rates=()
    for r in "${PASS_RATES[@]}"; do
        if [ "${best_mtu[$r]}" -eq "$mtu" ]; then
            same_rates+=("$r")
        fi
    done
    displayed+=("$mtu")
    echo -e "    ${color}成功率 ≥ ${same_rates[*]}% : 裸网 MTU=$mtu, 推荐 WARP MTU=$warp_mtu${NC}"
done

echo -e "\n[*] 说明："
echo -e "    绿色 (100%) : 最稳，几乎不会丢包或连接失败"
echo -e "    黄色 (≥90%) : 稳定且速度较快，少量丢包可接受"
echo -e "    红色 (≥80%) : 最大吞吐，可能出现偶尔失败，风险较高"
echo -e "    注：如果多个成功率档位的 MTU 相同，则只显示一次"
