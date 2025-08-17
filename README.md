# WARP MTU Test Script / WARP MTU 测试脚本

---

## English

### Why You Need This Script

When using Cloudflare WARP, you might encounter:

- Telegram works, but websites cannot load (ERR_CONNECTION_CLOSED).  
- Some websites are unstable or slow.  
- Fixed MTU settings may be unstable across different VPS or network environments.  

These problems are often caused by **improper MTU (Maximum Transmission Unit) settings**.

### MTU Introduction

- MTU represents the maximum packet size (in bytes) that a network interface can send in a single transmission.  
- WARP uses WireGuard tunneling, which adds ~80 bytes of header overhead.  
- If packets exceed the tunnel's effective MTU:  
  - They may be dropped by routers  
  - Websites may fail to load or connections may reset  
  - Telegram may work, but web browsing fails  

### How the Script Works

1. **Initial MTU Range**  
   - Define `[MIN_MTU, MAX_MTU]` based on physical NIC and WireGuard overhead.  
   - MIN_MTU ensures packets are deliverable even if path MTU is limited.  
   - MAX_MTU references standard Ethernet MTU (1500) minus WireGuard headers.

2. **ICMP Don't Fragment Test**  
   - Use `DF` flag to prevent fragmentation.  
   - Success → current MTU can traverse the tunnel.  
   - Failure → MTU exceeds path allowance.

3. **Multi-Round Statistics**  
   - Send `N` ICMP packets per MTU, record success probability `p = success / N`.  
   - Map `p` to stability levels:
     - `p = 1.0` → safest  
     - `0.9 ≤ p < 1.0` → high-speed stable  
     - `0.8 ≤ p < 0.9` → maximum throughput  

4. **Binary Search Optimization**  
   - Use binary search to efficiently find maximum MTU.  
   - Complexity: O(log2(MAX_MTU-MIN_MTU))  

5. **Error Buffer & Randomness Handling**  
   - Multi-round tests reduce transient network errors.  
   - Color-coded output shows stability:
     - Green → 100%  
     - Yellow → ≥90%  
     - Red → ≥80%

6. **IPv4 / IPv6 Independent Testing**  
   - Test both protocols separately; IPv6 is more sensitive to MTU issues.  
   - Each protocol has independent optimal MTU.

7. **Final Recommendation**  
   - Output three levels of MTU based on probability and stability.  
   - Users can choose based on preference: stable-first or throughput-first.  

> ⚠️ Assumes static network path; dynamic routing may cause slight variations.

### Benefits

- Avoid blind MTU tuning  
- Ensure stable WARP tunnel across different networks  
- Improve website access speed while keeping Telegram, games, or other apps functional  

### Run it

Linux:

```bash
bash <(curl -Ls https://lax.xx.kg/https://raw.githubusercontent.com/ZedWAre-HK/WARP-MTU-TESTER/refs/heads/main/WARP-MTU-TESTER.sh)

---

## 中文

### 为什么需要这个脚本

在使用 Cloudflare WARP 时，你可能遇到以下问题：

- Telegram 可以正常收发消息，但网页无法访问（ERR_CONNECTION_CLOSED）。  
- 某些网站访问不稳定，或者速度时快时慢。  
- 在不同 VPS 或网络环境下，固定 MTU 设置可能不稳定。  

这些问题通常由 **不合理的 MTU（最大传输单元）设置** 引起。

### MTU 简介

- MTU 表示网络接口一次能够发送的最大数据包大小（字节数）。  
- WARP 使用 WireGuard 隧道加密流量，会增加约 80 字节的头部开销。  
- 如果数据包超过隧道可用 MTU：  
  - 数据包可能被路由器丢弃  
  - 网站无法访问或连接重置  
  - Telegram 消息正常，但网页无法访问  

### 脚本计算原理

1. **初始 MTU 范围**  
   - 定义 `[MIN_MTU, MAX_MTU]`，根据物理网卡和 WireGuard 开销设置。  
   - MIN_MTU 保证即使路径 MTU 有限制，数据包也能到达目标。  
   - MAX_MTU 参考标准以太网 MTU（1500）减去 WireGuard 包头。

2. **ICMP 分片禁止测试**  
   - 使用 `DF` 标志（Linux: `-M do`），防止中间节点分片。  
   - 成功 → 当前 MTU 可以通过隧道。  
   - 失败 → MTU 超过路径允许。

3. **多轮统计**  
   - 每个 MTU 发送 `N` 个 ICMP 包，记录成功率 `p = 成功次数 / N`。  
   - 成功率映射到稳定性等级：
     - `p = 1.0` → 极稳  
     - `0.9 ≤ p < 1.0` → 高速稳态  
     - `0.8 ≤ p < 0.9` → 最大吞吐量

4. **二分查找优化**  
   - 使用二分搜索快速找到最优 MTU  
   - 算法复杂度：O(log2(MAX_MTU-MIN_MTU))

5. **误差缓冲与偶然性处理**  
   - 多轮测试减少瞬时网络波动误差  
   - 彩色输出显示稳定性：
     - 绿色 → 100%  
     - 黄色 → ≥90%  
     - 红色 → ≥80%

6. **IPv4 / IPv6 独立测试**  
   - 分别测试两种协议，IPv6 对 MTU 问题更敏感  
   - 每种协议有独立最优 MTU

7. **最终推荐**  
   - 输出三个档位的 MTU 值，根据成功率和稳定性选择  
   - 用户可选择“稳健优先”或“吞吐优先”

> ⚠️ 假设网络路径在测试期间保持静态，动态路由可能导致微小偏差。

### 使用价值

- 避免手动盲调 MTU  
- 保证 WARP 隧道在不同网络环境下稳定运行  
- 提升网页访问速度，同时保证 Telegram、游戏或其他应用正常使用

### 运行它

Linux:

```bash
bash <(curl -Ls https://lax.xx.kg/https://raw.githubusercontent.com/ZedWAre-HK/WARP-MTU-TESTER/refs/heads/main/WARP-MTU-TESTER.sh)
```
