#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} +
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" {} +
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" {} +

#修改默认WIFI账号密码（BE10000 射频是 2.4G + 5.2G + 5.8G，密码三频共用）
#注：ath12k 把 5.2G 和 5.8G 都上报成 band=5g，只能靠 radio.freq_ranges 的下界区分
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
ROUTER_TOOL="./package/emortal/luci-app-router-tool/root/etc/config/router-tool"

SSID_2G=${WRT_SSID:-OWRT}
SSID_52=${WRT_SSID_5_2G:-$SSID_2G}
SSID_58=${WRT_SSID_5_8G:-$SSID_2G}

#这些字符会破坏 ucode 字符串或 sed 表达式，直接失败比编出一个连不上 WiFi 的固件好
if printf '%s' "$SSID_2G$SSID_52$SSID_58$WRT_WORD" | grep -q "['#&\\\\]"; then
	echo "::error::SSID / WiFi 密码不能包含单引号、#、& 或反斜杠"
	exit 1
fi
if [ ${#WRT_WORD} -lt 8 ]; then
	echo "::error::WiFi 密码至少 8 位（当前 ${#WRT_WORD} 位）"
	exit 1
fi

if [ -f "$WIFI_UC" ]; then
	#两个 5G 射频的 band_name 相同，用频段下界（kHz）5500000 区分 5.2G / 5.8G
	sed -i \
		-e "s#^set \${si}\.ssid=.*#set \${si}.ssid='\${band_name == '2g' ? '$SSID_2G' : ((radio.freq_ranges?.[0]?.[0] ?? 5170000) < 5500000 ? '$SSID_52' : '$SSID_58')}'#" \
		-e "s#^set \${si}\.key=.*#set \${si}.key='$WRT_WORD'#" \
		"$WIFI_UC"

	#上游改动会让补丁失配，此时必须报出来，否则会静默回落成默认 SSID
	grep -Fq "radio.freq_ranges?.[0]?.[0]" "$WIFI_UC" ||
		echo "::warning::三频 SSID 补丁未生效，mac80211.uc 结构可能已变化"
fi

#router-tool 首次开机向导的默认值（单值，用 2.4G 的）
if [ -f "$ROUTER_TOOL" ]; then
	sed -i -e "s/ssid '.*'/ssid '$SSID_2G'/g" -e "s/key '.*'/key '$WRT_WORD'/g" "$ROUTER_TOOL"
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
