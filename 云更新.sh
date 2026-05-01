#!/system/bin/sh
start_ui
# ======下载云端配置 ===========
CONFIG_URL="https://gist.githubusercontent.com/guaizyy/13bc149b77a97b0c4d046fd9ef4a9889/raw/79801c5fbb4bdfe880754bfbecec9eed835860c9/game_list.conf"
#===============================
start_ui() {
    clear
    echo "======================================"
    echo "        🚀 云更新系统启动中..."
    echo "======================================"

    bar=""
    for i in $(seq 1 20); do
        bar="${bar}#"
        printf "\r加载中: [%-20s] %d%%" "$bar" "$((i*5))"
        sleep 0.05
    done
    echo ""
}
SECRET_KEY="guaizyy"

check_auth() {
    txt="$1"
    echo "$txt" | grep -q "KEY=$SECRET_KEY" || {
        echo "❌ 非官方更新源"
        exit 1
    }
}
# ===================== 云端更新配置（只需要这里设置一次） =====================
# 本地版本自动从脚本自身读取，不再需要手动修改
NOTICE_URL="https://raw.githubusercontent.com/guaizyy/binbin/refs/heads/main/云更新.sh"

# ===================== 工具函数 =====================
# 版本比较（必须在最前）
version_gt() {
    [ "$(echo -e "$1\n$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)" = "$1" ] && [ "$1" != "$2" ]
}
# 1. 获取本地版本号（自动从脚本里读，不用手动改）
get_local_version() {
    grep "^LOCAL_VER=" "$0" | head -n1 | cut -d= -f2 | tr -d '"'
}

# 2. 下载工具
get_raw() {
    curl -sL --connect-timeout 10 "$1"
}

# 3. 后台检查更新（只在脚本启动时运行一次）
auto_check_update() {
    (
        txt=$(get_raw "$NOTICE_URL")
        [ -z "$txt" ] && return

        remote_ver=$(echo "$txt" | grep "^VERSION=" | cut -d= -f2)
        local_ver=$(get_local_version)

        if version_gt "$remote_ver" "$local_ver"; then
            echo "$remote_ver" > /data/local/tmp/ver_new
        else
            rm -f /data/local/tmp/ver_new 2>/dev/null
        fi
    ) &
}

# 云同步配置
sync_game_list() {
    echo "☁️ 正在同步配置..."

    cfg=$(get_raw "$CONFIG_URL")

    if [ -z "$cfg" ]; then
        echo "❌ 同步失败"
        return
    fi

    echo "$cfg" > "$GAME_LIST_FILE"

    echo "✅ 同步完成"
}

# 4. 手动检查更新菜单
check_update_now() {
    clear
    echo "========================================"
    echo "           🔍 检查更新 🔍"
    echo "========================================"

    local_ver=$(get_local_version)
    echo "本地版本：$local_ver"

    txt=$(get_raw "$NOTICE_URL")
# 判断是不是正常文本
echo "$txt" | grep -q "VERSION=" || {
    echo "❌ 公告格式错误或地址错误"
    read
    return
}
    if [ -z "$txt" ]; then
        echo "❌ 获取公告失败"
        read
        return
    fi

    remote_ver=$(echo "$txt" | grep "^VERSION=" | cut -d= -f2)
    remote_url=$(echo "$txt" | grep "^URL=" | cut -d= -f2)
    remote_msg=$(echo "$txt" | grep "^MSG=" | cut -d= -f2- | sed 's/\\n/\n/g')
    remote_md5=$(echo "$txt" | grep "^MD5=" | cut -d= -f2)

    echo "云端版本：$remote_ver"
    echo -e "\n📢 更新公告："
    echo -e "$remote_msg"

    if version_gt "$remote_ver" "$local_ver"; then
        echo -e "\n🚀 发现新版本，是否更新？(y/n)"
        read -n1 ans

        if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
            echo -e "\n🔽 下载中..."

            tmp_file="/data/local/tmp/update.sh"
            get_raw "$remote_url" > "$tmp_file"

            # ✅ MD5 校验（可选但强烈建议）
            if [ -n "$remote_md5" ]; then
            remote_md5=$(echo "$txt" | grep "^MD5=" | cut -d= -f2)
                local_md5=$(md5sum "$tmp_file" | awk '{print $1}')
                if [ "$local_md5" != "$remote_md5" ]; then
                    echo "❌ 校验失败，可能被篡改！"
                    rm -f "$tmp_file"
                    read
                    return
                fi
            fi

            chmod +x "$tmp_file"
            cp "$tmp_file" "$0"

            echo "✅ 更新成功！请重新运行脚本"
            rm -f "$tmp_file"
            rm -f /data/local/tmp/ver_new
            exit 0
        fi
    else
        echo -e "\n✅ 已是最新版"
    fi

    echo -e "\n按回车返回"
    read
}

# ===================== 原有逻辑（完全不动） =====================
# 配置路径
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="${SCRIPT_DIR}/启动配置文件.txt"
GAME_LIST_FILE="${SCRIPT_DIR}/game_list.conf"

# 初始化配置
[ -f "$CONFIG_FILE" ] || echo -n "0" > "$CONFIG_FILE"
CONFIG=$(cat "$CONFIG_FILE" 2>/dev/null | tr -d ' \n\r')

# 初始化游戏列表
if [ ! -f "$GAME_LIST_FILE" ]; then
cat > "$GAME_LIST_FILE" <<EOF
com.tencent.tmgp.pubgmhd|com.epicgames.ue4.GameActivity|/data/葫芦娃/衍生/*.sh|0
EOF
fi

# 工具函数
show_script_info() {
    local script_path="$1"
    echo "========================================"
    echo "📂 当前脚本路径：$script_path"

    local count=0
    local files=""

    if echo "$script_path" | grep -q ","; then
        local OLD_IFS="$IFS"
        IFS=","
        for f in $script_path; do
            count=$((count + 1))
            files="$files\n[$count] $f"
        done
        IFS="$OLD_IFS"
        echo -e "\n📋 已配置多个脚本，共 $count 个："
        echo -e "$files"
    else
        if echo "$script_path" | grep -q "\*"; then
            local dir=$(dirname "$script_path")
            if [ -d "$dir" ]; then
                local sh_list=$(ls "$dir"/*.sh 2>/dev/null)
                local sh_count=$(echo "$sh_list" | wc -l)
                echo -e "\n📍 通配符路径：$script_path"
                echo "🔢 实际匹配到的 .sh 文件数量：$sh_count"

                if [ "$sh_count" -eq 0 ]; then
                    echo "⚠️  目录内没有找到 .sh 文件！"
                elif [ "$sh_count" -gt 1 ]; then
                    echo "⚠️  警告：该文件夹内有多个 .sh 文件！"
                fi

                echo -e "\n📄 文件列表："
                echo "$sh_list" | while read f; do
                    [ -n "$f" ] && echo " - $f"
                done
            else
                echo -e "\n❌ 目录不存在：$dir"
            fi
        else
            [ -f "$script_path" ] && echo "✅ 单个脚本，文件存在：$script_path" || echo "❌ 单个脚本，不存在：$script_path"
        fi
    fi
    echo "========================================"
}

# 单次正常模式入口
[ "$1" = "--normal" ] && CONFIG="1"

# 启动时后台自动检查更新
auto_check_update

# ===================== 修改模式 =====================
if [ "$CONFIG" = "0" ]; then
    while true; do
        clear
        echo "========================================"
        echo "⚙️ 修改主菜单 $(date +%H:%M:%S)"
        local_ver=$(get_local_version)
        echo "           版本：$local_ver"
        [ -f /data/local/tmp/ver_new ] && echo "      🔴 有新版本：$(cat /data/local/tmp/ver_new)"
        echo "========================================"
        echo " 1. 获取当前组件名"
        echo " 2. 修改游戏配置"
        echo " 3. 添加游戏"
        echo " 4. 删除游戏"
        echo " 5. 切换正常模式"
        echo " 6. 检查更新"
        echo " 7. 同步云配置"
        echo " 0. 退出"
        echo "========================================"
        echo -n "请选择: "
        read opt

        case "$opt" in
            1)
                clear
                echo "========================================"
                echo "          📶 获取当前组件名 📶          "
                echo "========================================"
                echo "请先切回游戏界面，等待5秒..."
                echo
                res=$(sleep 5 && dumpsys window | grep mCurrentFocus 2>/dev/null)
                if [ -z "$res" ]; then
                    echo "❌ 获取组件名失败！"
                else
                    component=$(echo "$res" | awk '{print $2}' | tr -d '}')
                    echo "✅ 获取成功！"
                    echo "------------------------"
                    echo "$component"
                    echo "------------------------"
                fi
                echo
                echo -n "按回车返回..."
                read dummy
                ;;

            2)
                while true; do
                    clear
                    echo "========================================"
                    echo " 🎮 启动项修改 🎮 "
                    echo "========================================"
                    local idx=1
                    while IFS='|' read p a s pr; do
                        [ -n "$p" ] && echo " $idx. $p" && idx=$((idx + 1))
                    done < "$GAME_LIST_FILE"
                    echo " 0. 返回"
                    echo "========================================"
                    echo -n "选择序号: "
                    read n
                    { [ -z "$n" ] || [ "$n" = "0" ]; } && break
                    echo "$n" | grep -q "^[0-9]*$" || { echo "⚠️ 输入不合法"; sleep 1; continue; }
                    
                    local line=$(sed -n "${n}p" "$GAME_LIST_FILE")
                    [ -z "$line" ] && { echo "❌ 序号不存在"; sleep 1; continue; }
                    
                    local p=$(echo "$line" | cut -d'|' -f1)
                    local a=$(echo "$line" | cut -d'|' -f2)
                    local s=$(echo "$line" | cut -d'|' -f3)
                    local pr=$(echo "$line" | cut -d'|' -f4)
                    
                    # 新增：判断是否有多个脚本，让用户选择改哪个
                    local target_script=""
                    local target_param_idx=0
                    
                    if echo "$s" | grep -q ","; then
                        # 有多个脚本，让用户选
                        clear
                        echo "========================================"
                        echo " 🎯 选择要修改的脚本 🎯 "
                        echo "========================================"
                        local script_idx=1
                        local OLD_IFS="$IFS"
                        IFS=","
                        for sc in $s; do
                            echo " $script_idx. $sc"
                            script_idx=$((script_idx + 1))
                        done
                        echo " 0. 返回"
                        echo "========================================"
                        IFS="$OLD_IFS"
                        echo -n "选择: "
                        read script_opt
                        [ -z "$script_opt" ] && continue
                        [ "$script_opt" = "0" ] && continue
                        target_param_idx=$script_opt
                        # 获取选中的脚本路径
                        target_script=$(echo "$s" | cut -d',' -f$script_opt)
                    else
                        # 只有一个脚本，直接用它
                        target_script="$s"
                        target_param_idx=1
                    fi
                    
                    clear
                    echo "========================================"
                    echo " 🎯 正在修改: $p 🎯 "
                    echo " 脚本: $target_script"
                    echo "========================================"
                    show_script_info "$target_script"
                    echo
                    echo " 1. 修改组件名"
                    echo " 2. 修改脚本路径"
                    echo " 3. 修改打印内容"
                    echo " 4. 清空脚本"
                    echo " 0. 返回"
                    echo -n "选择: "
                    read c
                    [ -z "$c" ] && continue
                    
                    local newline=""
                    if [ "$c" = "1" ]; then
                        echo -n "新组件名: "
                        read newa
                        newline="$p|$newa|$s|$pr"
                    elif [ "$c" = "2" ]; then
                        echo -n "新脚本路径: "
                        read news
                        # 如果原来有多个脚本，需要替换对应的那个
                        if echo "$s" | grep -q ","; then
                            local before=""
                            local after=""
                            local i=1
                            OLD_IFS="$IFS"
                            IFS=","
                            for sc in $s; do
                                if [ "$i" -lt "$target_param_idx" ]; then
                                    [ -z "$before" ] && before="$sc" || before="$before,$sc"
                                elif [ "$i" -gt "$target_param_idx" ]; then
                                    [ -z "$after" ] && after="$sc" || after="$after,$sc"
                                fi
                                i=$((i + 1))
                            done
                            IFS="$OLD_IFS"
                            if [ -n "$before" ] && [ -n "$after" ]; then
                                news="$before,$news,$after"
                            elif [ -n "$before" ]; then
                                news="$before,$news"
                            elif [ -n "$after" ]; then
                                news="$news,$after"
                            fi
                        fi
                        newline="$p|$a|$news|$pr"
                    elif [ "$c" = "3" ]; then
                        echo -n "新输入内容: "
                        read -r newpr
                        # 替换对应位置的参数
                        local new_pr_all=""
                        local i=1
                        OLD_IFS="$IFS"
                        IFS="|"
                        for param in $pr; do
                            if [ "$i" -eq "$target_param_idx" ]; then
                                [ -z "$new_pr_all" ] && new_pr_all="$newpr" || new_pr_all="$new_pr_all|$newpr"
                            else
                                [ -z "$new_pr_all" ] && new_pr_all="$param" || new_pr_all="$new_pr_all|$param"
                            fi
                            i=$((i + 1))
                        done
                        IFS="$OLD_IFS"
                        newline="$p|$a|$s|$new_pr_all"
                    elif [ "$c" = "4" ]; then
                        newline="$p|$a|NULL|NULL"
                    else
                        continue
                    fi
                    
                    sed -i "${n}s/.*/$newline/" "$GAME_LIST_FILE"
                    echo "✅ 修改成功"
                    sleep 1
                done
                ;;

            3)
                clear
                echo "========================================"
                echo "          ➕ 添加游戏 ➕                "
                echo "========================================"
                echo -n "游戏名: "
                read p
                echo -n "游戏组件名: "
                read a
                echo -n "要添加几个执行脚本，请输入数字: "
                read num

                echo "$num" | grep -q "^[0-9]*$" || { echo "⚠️  输入无效"; sleep 1; continue; }

                local s=""
                local pr=""

                if [ "$num" -eq 0 ]; then
                    s="NULL"
                    pr="NULL"
                elif [ "$num" -eq 1 ]; then
                    echo -n "脚本完整路径: "
                    read one_s
                    s="$one_s"
                    show_script_info "$s"
                    echo -n "打印内容: "
                    read -r one_pr
                    pr="$one_pr"
                else
                    local i=1
                    while [ "$i" -le "$num" ]; do
                        echo -n "第 $i 脚本路径: "
                        read one
                        [ -z "$s" ] && s="$one" || s="$s,$one"
                        i=$((i + 1))
                    done
                    show_script_info "$s"

                    i=1
                    while [ "$i" -le "$num" ]; do
                        echo -n "第 $i 打印内容: "
                        read -r one
                        [ -z "$pr" ] && pr="$one" || pr="$pr|$one"
                        i=$((i + 1))
                    done
                fi

                # 只追加，不覆盖、不删除！
                printf "%s\n" "$p|$a|$s|$pr" >> "$GAME_LIST_FILE"

                echo "✅ 添加成功"
                sleep 1
                ;;



            4)
                while true; do
                    clear
                    echo "========================================"
                    echo "          ❌ 删除游戏 ❌                "
                    echo "========================================"

                    # 显示序号（不嵌套任何if）
                    idx=1
                    while IFS='|' read -r p a s pr || [ -n "$p" ]; do
                        if [ -n "$p" ]; then
                            echo " $idx. $p"
                            idx=`expr $idx + 1`
                        fi
                    done < "$GAME_LIST_FILE"

                    echo " 0. 返回"
                    echo "========================================"
                    echo -n "选择序号: "
                    read n

                    # 处理输入
                    if [ -z "$n" ]; then
                        echo "⚠️  取消删除"
                        sleep 1
                        continue
                    fi

                    if [ "$n" = "0" ]; then
                        break
                    fi

                    # 检查数字
                    if ! echo "$n" | grep -q "^[0-9]*$"; then
                        echo "⚠️  不合法"
                        sleep 1
                        continue
                    fi

                    # 计算真实行号
                    real_line=0
                    count=0
                    while IFS='|' read -r p a s pr || [ -n "$p" ]; do
                        if [ -n "$p" ]; then
                            count=`expr $count + 1`
                            if [ "$count" -eq "$n" ]; then
                                real_line=`expr $real_line + 1`
                                break
                            fi
                        fi
                        real_line=`expr $real_line + 1`
                    done < "$GAME_LIST_FILE"

                    if [ "$real_line" -eq 0 ]; then
                        echo "❌ 序号不存在"
                        sleep 1
                        continue
                    fi

                    sed -i "${real_line}d" "$GAME_LIST_FILE"
                    echo "✅ 删除成功"
                    sleep 1
                done
                ;;



            5)
                exec sh "$0" --normal
                ;;

            6)
                check_update_now
                ;;
            7)
                sync_game_list
                echo "同步配置成功"
                echo "按回车返回"
                read dummy
                ;;
            0)
                echo "❌主程序退出❌"
                exit 0
                ;;

            *)
                echo "⚠️  输入错误"
                sleep 1
                ;;
        esac
    done
fi

# ===================== 正常模式 =====================
if [ "$CONFIG" = "1" ]; then
    clear
    echo "========================================"
    echo "      🔄 正常模式运行中 🔄      "
    echo "  (5秒内没有检测到游戏，自动退出)  "
    echo "========================================"

    local timeout=5
    local start_time=$(date +%s)

    while true; do
        local now=$(date +%s)
        local diff=$((now - start_time))
        [ "$diff" -ge "$timeout" ] && { echo "⏹️  超时退出"; exit 0; }

        while IFS='|' read pkg act scr allpr; do
            [ -z "$pkg" ] && continue
            if pidof "$pkg" >/dev/null 2>&1; then
                echo
                echo "✅ 检测到游戏：$pkg"
                am start -n "$pkg/$act" >/dev/null 2>&1

                if [ "$scr" != "NULL" ] && [ -n "$scr" ]; then
                    echo "▶️  开始执行脚本..."

                    OLD_IFS="$IFS"
                    IFS=","
                    for sc in $scr; do
                        IFS="$OLD_IFS"

                        if [ -f "$sc" ]; then
                            echo "▶️  执行：$sc"
                            # 进入脚本所在目录再执行 → 关键修复
                            (
                                cd "$(dirname "$sc")"
                                echo "$allpr" | sh "$sc"
                            )
                        else
                            for f in $sc; do
                                [ -f "$f" ] || continue
                                echo "▶️  执行：$f"
                                (
                                    cd "$(dirname "$f")"
                                    echo "$allpr" | sh "$f"
                                )
                            done
                        fi
                    done
                    IFS="$OLD_IFS"
                else
                    echo "ℹ️  未配置脚本"
                fi

                echo
                echo "🏁 执行完成"
                sleep 2
                exit 0
            fi
        done < "$GAME_LIST_FILE"

        sleep 1
    done
fi



# 这里只需要在脚本发布时写一次，以后更新不用改！
VERSION="1.1"
URL="https://raw.githubusercontent.com/xxx/云更新.sh"
MD5="41a2b6c3b01d29fdc87239ca4262f026"
MSG="1.更新云配置"
LOCAL_VER="1.0"
