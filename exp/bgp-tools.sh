#!/bin/bash

# BGP实验工具脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查BGP邻居状态
check_neighbors() {
    echo -e "${GREEN}=== BGP邻居状态检查 ===${NC}"
    for router in r1 r2 r3; do
        echo -e "${YELLOW}Router $router:${NC}"
        docker exec -it bgp-$router gobgp neighbor
        echo ""
    done
}

# 查看路由表
show_routes() {
    echo -e "${GREEN}=== BGP路由表 ===${NC}"
    for router in r1 r2 r3; do
        echo -e "${YELLOW}Router $router 路由表:${NC}"
        # 检查容器是否运行
        if docker exec bgp-$router gobgp global rib --quiet 2>/dev/null | grep -E "(192.168|Next Hop|AS Path)"; then
            :  # 已显示路由
        else
            echo "  无BGP路由或容器未运行"
        fi
        echo ""
    done
}

# 测试连通性
test_connectivity() {
    echo -e "${GREEN}=== 连通性测试 ===${NC}"
    
    # 从R1测试到其他网络
    echo -e "${YELLOW}从R1测试连通性:${NC}"
    docker exec -it bgp-r1 ping -c 3 172.20.2.101 2>/dev/null && echo "R1 -> R2: OK" || echo "R1 -> R2: FAILED"
    docker exec -it bgp-r1 ping -c 3 172.20.1.102 2>/dev/null && echo "R1 -> R3: OK" || echo "R1 -> R3: FAILED"
    
    echo ""
}

# 监控BGP更新
monitor_updates() {
    echo -e "${GREEN}=== 实时监控BGP更新 (按Ctrl+C停止) ===${NC}"
    docker exec -it bgp-r1 gobgp monitor global rib
}

# 模拟链路故障
simulate_failure() {
    router=$1
    if [ -z "$router" ]; then
        echo "用法: simulate_failure <router_name>"
        return 1
    fi

    # 输出当前路由表

    echo -e "${GREEN}=== 当前路由表 ===${NC}"
    for r in r1 r2 r3; do
        echo -e "${YELLOW}Router $r 路由表:${NC}"
        docker exec bgp-$r gobgp global rib --quiet | grep -E "(192.168|Next Hop|AS Path)" || echo "  无路由"
        echo ""
    done
    
    echo -e "${RED}=== 模拟 $router 故障 ===${NC}"
    docker pause bgp-$router
    echo "路由器 $router 已暂停，观察路由变化..."
    sleep 5
    
    # 只显示其他运行中路由器的路由表
    echo -e "${GREEN}=== 其他路由器的路由表 ===${NC}"
    for r in r1 r2 r3; do
        if [ "$r" != "$router" ]; then
            echo -e "${YELLOW}Router $r 路由表:${NC}"
            docker exec bgp-$r gobgp global rib --quiet | grep -E "(192.168|Next Hop|AS Path)" || echo "  无路由"
            echo ""
        fi
    done
    
    echo -e "${GREEN}=== 恢复 $router ===${NC}"
    docker unpause bgp-$router
    echo "路由器 $router 已恢复，等待BGP收敛..."
    sleep 10
    show_routes
}

# 主菜单
show_menu() {
    echo -e "${GREEN}=== GoBGP实验工具 ===${NC}"
    echo "1. 检查BGP邻居状态"
    echo "2. 查看路由表"
    echo "3. 测试连通性"
    echo "4. 监控BGP更新"
    echo "5. 模拟链路故障"
    echo "6. 显示帮助"
    echo "7. 初始化路由宣告"
    echo "0. 退出"
}

# 初始化路由宣告
init_routes() {
    echo -e "${GREEN}=== 初始化路由宣告 ===${NC}"
    
    # R1宣告192.168.1.0/24
    echo "R1: 宣告 192.168.1.0/24"
    docker exec bgp-r1 gobgp global rib add 192.168.1.0/24

    # R2宣告192.168.2.0/24  
    echo "R2: 宣告 192.168.2.0/24"
    docker exec bgp-r2 gobgp global rib add 192.168.2.0/24

    # R3宣告192.168.3.0/24
    echo "R3: 宣告 192.168.3.0/24"
    docker exec bgp-r3 gobgp global rib add 192.168.3.0/24

    echo "路由宣告完成，等待传播..."
    sleep 3
    show_routes
}
show_help() {
    echo -e "${GREEN}=== 常用命令 ===${NC}"
    echo "docker exec -it bgp-r1 gobgp neighbor                    # 查看邻居状态"
    echo "docker exec -it bgp-r1 gobgp global rib                 # 查看路由表"
    echo "docker exec -it bgp-r1 gobgp global rib -a ipv4 192.168.2.0/24  # 查看特定路由"
    echo "docker exec -it bgp-r1 gobgp monitor global rib         # 监控路由变化"
    echo "docker exec -it bgp-r1 gobgp policy                     # 查看策略"  
    echo "docker logs bgp-r1                                      # 查看日志"
}

# 如果有参数直接执行对应功能
case "$1" in
    "neighbors") check_neighbors ;;
    "routes") show_routes ;;
    "test") test_connectivity ;;
    "monitor") monitor_updates ;;
    "fail") simulate_failure $2 ;;
    "help") show_help ;;
    "init") init_routes ;;
    *)
        # 交互式菜单
        while true; do
            show_menu
            read -p "请选择 (0-7): " choice
            case $choice in
                1) check_neighbors ;;
                2) show_routes ;;
                3) test_connectivity ;;
                4) monitor_updates ;;
                5) 
                    read -p "输入路由器名称 (r1/r2/r3): " router
                    simulate_failure $router
                    ;;
                6) show_help ;;
                7) init_routes ;;
                0) echo "退出"; exit 0 ;;
                *) echo "无效选择" ;;
            esac
            echo ""
        done
        ;;
esac
