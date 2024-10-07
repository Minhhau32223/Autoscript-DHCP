#!/bin/bash
#---------------Khai báo biến
 
conf_file="/etc/dhcp/dhcpd.conf"


#-----------------------------------------------Pre-Start
# Kiểm tra root 
if [[ $EUID -ne 0 ]]; then
   	echo "Please run the script as root."
   	exit 1
fi
# Kiểm tra cài đặt
if rpm -q dhcp > /dev/null; then
   	echo "DHCP was installed"
else
	echo "DHCP haven't installed yet"
        echo "Download DHCP package"
	yum install -y dhcp
	cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example /etc/dhcp/dhcpd.conf
fi

# ---------------------------------------------Utils
# Hàm kiểm tra định dạng địa chỉ IP 
function is_valid_ip() {
  local  ip=$1
  local  stat=1
  for i in 1 2 3 4; do
    if [ ${ip#*.} -z ] && [ -z ${ip%$*.*} ]; then
      break
    fi
    ip=${ip#*.}
    if (( $(($ip%256)) > 255 )); then
      stat=0
      break
    fi
  done
  echo $stat
}
#--------------------------------------------Scope
# Hàm kiểm tra xem một scope đã tồn tại chưa
function check_scope_exists() {
  subnet="$1"
  grep -q "subnet $subnet" /etc/dhcp/dhcpd.conf
}
# Hàm để cấu hình DHCP server
function create_scope() {
  read -p "Nhập subnet (ví dụ: 192.168.1.0): " subnet
  read -p "Nhập netmask (ví dụ: 255.255.255.0): " netmask
  echo "-Nhập dãy ip cấp phát-"
  read -p "Nhập địa chỉ IP bắt đầu: " start
  read -p "Nhập địa chỉ IP kết thúc: " end
  read -p "Nhập tên máy chủ miền (cách nhau bằng dấu cách): " dns_servers
  read -p "Nhập tên miền: " domain_name
  read -p "Nhập địa chỉ routers: " routers
  read -p "Nhập địa chỉ broadcast: " broadcast
  read -p "Nhập địa chỉ DNS server: " dns_servers_add
  read -p "Nhập thời gian cho thuê mặc định: " lease_time
  read -p "Nhập thời gian cho thuê tối đa: " lease_time_max
# Kiểm tra xem một scope đã tồn tại chưa
  if check_scope_exists "$subnet"; then
  echo "Scope đã tồn tại!"
  else
 # Tạo cấu hình
 config_lines=()
 config_lines+=("subnet $subnet netmask $netmask {")
 config_lines+=("  range $start $end;")
 config_lines+=("  option domain-name-servers $dns_servers;")
 config_lines+=("  option domain-name \"$domain_name\";")
 config_lines+=("  option routers $routers;")
 config_lines+=("  option broadcast-address $broadcast;")
 config_lines+=("  option domain-name-servers $dns_servers_add;")
 config_lines+=("  default-lease-time $lease_time;")
 config_lines+=("  option broadcast-address $lease_time_max;")
 config_lines+=("}")
 # Ghi vào file cấu hình
 printf "%s\n" "${config_lines[@]}" >> "$conf_file"
 echo "Tạo Scope thành công"
 fi
}
function find_scope(){
 read -p "Nhập subnet hiện tại của scope: " old_subnet
  
 if ! check_scope_exists "$old_subnet"; then
  echo "Scope không tồn tại!"
  return
 fi
# In thông tin scope
  echo "Thông tin chi tiết của scope $old_subnet:"
  sed -n '/^subnet '$old_subnet'/,/^}/p' "$conf_file"
}
function update_scope() {
  read -p "Nhập subnet hiện tại của scope: " old_subnet
  
 if ! check_scope_exists "$old_subnet"; then
  echo "Scope không tồn tại!"
  return
 fi
# In thông tin scope
  echo "Thông tin chi tiết của scope $old_subnet:"
  sed -n '/^subnet '$old_subnet'/,/^}/p' "$conf_file"
  # Nhập thông tin mới cần cập nhật
  read -p "Nhập subnet (ví dụ: 192.168.1.0): " subnet
  read -p "Nhập netmask (ví dụ: 255.255.255.0): " netmask
  echo "-Nhập dãy ip cấp phát-"
  read -p "Nhập địa chỉ IP bắt đầu: " start
  read -p "Nhập địa chỉ IP kết thúc: " end
  read -p "Nhập tên máy chủ miền (cách nhau bằng dấu cách): " dns_servers
  read -p "Nhập tên miền: " domain_name
  read -p "Nhập địa chỉ routers: " routers
  read -p "Nhập địa chỉ broadcast: " broadcast
  read -p "Nhập địa chỉ DNS server: " dns_servers_add
  read -p "Nhập thời gian cho thuê mặc định (giây) :" lease_time
  read -p "Nhập thời gian cho thuê tối đa (giây) :" lease_time_max

 # Tạo cấu hình
 config_lines=()
 config_lines+=("subnet $subnet netmask $netmask {")
 config_lines+=("  range $start $end;")
 config_lines+=("  option domain-name-servers $dns_servers;")
 config_lines+=("  option domain-name \"$domain_name\";")
 config_lines+=("  option routers $routers;")
 config_lines+=("  option broadcast-address $broadcast;")
 config_lines+=("  option domain-name-servers $dns_servers_add;")
 config_lines+=("  default-lease-time $lease_time;")
 config_lines+=("  option broadcast-address $lease_time_max;")
 config_lines+=("}")
 # Backup file cấu hình
 tmpfile=$(mktemp)
 cp "$conf_file" "$tmpfile"
# Xoá Scope
 sed -i "/^subnet $old_subnet/,/^}/d" "$conf_file"
# Kiem tra scope
 if check_scope_exists "$subnet"; then
  echo "Scope đã tồn tại!"
  mv "$tmpfile" "$conf_file" 
  else
  printf "%s\n" "${config_lines[@]}" >> "$conf_file"
  rm "$tmpfile"
  echo "Cập nhật Scope thành công"
fi
 
}
# Hàm xoá Scope
function delete_scope(){
 read -p "Nhập subnet cần xoá của scope: " old_subnet
 if ! check_scope_exists "$old_subnet"; then
  echo "Scope không tồn tại!"
  return
 else
 sed -i "/^subnet $old_subnet/,/^}/d" "$conf_file"
 echo "Xoá Scope thành công"
fi
}
# Hàm tạo host
function create_host() {
	read -p "Nhập tên host: " namehost
	read -p "Nhập địa chỉ MAC: " diachiMAC
	read -p "Nhập địa chỉ IP: " diachiIP
	new_MAC="hardware ethernet $diachiMAC;"
	new_IP="fixed-address $diachiIP;"
	test=0;	
	mapfile -t line < "$conf_file"
	for ((i=0;i<${#line[@]};i++))
	do
		if grep -q "$new_MAC" "$conf_file"; then
			echo "Đã tồn tại địa chỉ MAC"	
			test=1			
			break
		fi
		if grep -q "$new_IP" "$conf_file"; then
			echo "Đã tồn tại địa chỉ IP"	
			test=1			
			break
		fi		
	done
	if [ $test == 0 ];then

		new_host="host $namehost {
			 hardware ethernet $diachiMAC;
			 fixed-address $diachiIP;
			}"
	echo "$new_host" >> "$conf_file"
	echo "Tạo host thành công"
	fi
}
function delete_host(){
	read -p "Nhập tên host: " name
        sed -i "/host $name/,/}/d" "$conf_file"
        echo "Xoá host thành công"
}
# ----------------------------------------------DHCP
function start_dhcp() {
  systemctl daemon-reload
  systemctl enable dhcpd
  systemctl start dhcpd
  
}
function stop_dhcp() {
  systemctl stop dhcpd
  systemctl disable dhcpd
}
function restart_dhcp(){
 systemctl restart dhcpd
}
function fix_SElinux()
{
ausearch -c 'dhcpd' --raw | audit2allow -M my-dhcpd
semodule -i my-dhcpd.pp
}
function find_host(){
 read -p "Nhập tên host: " namehost
# In thông tin host
  echo "Thông tin chi tiết của host:"
  sed -n '/^host '$namehost'/,/^}/p' "$conf_file"
}
# Tạo Menu
while :
do
printf "╔═════════════════════════════════╗\n"
printf "║  DHCP AutoScript                ║\n"
printf "╠═════════════════════════════════╣\n"
printf "║-------Scope--------             ║\n"
printf "║ 1. Tạo scope                    ║\n"
printf "║ 2. Cập nhật scope               ║\n"
printf "║ 3. Tìm kiếm scope               ║\n"
printf "║ 4. Xoá scope                    ║\n"
printf "╠═════════════════════════════════╣\n"
printf "║-------Host---------             ║\n"
printf "║ 5. Tạo host                     ║\n"
printf "║ 6. Xoá host                     ║\n"
printf "║ 7. Tìm kiếm host                ║\n"
printf "╠═════════════════════════════════╣\n"
printf "║ 8. Chạy DHCP                    ║\n"
printf "║ 9. Ngừng DHCP                   ║\n"
printf "║ 10. Restart DHCP                ║\n"
printf "║ 11. Allow script                ║\n"
printf "║ 12. Thoát                       ║\n"
printf "╚═════════════════════════════════╝\n"
read -p "Nhập lựa chọn " choice
if [[ "$choice" == "1" ]]; then
    create_scope
elif [[ "$choice" == "2" ]]; then
    update_scope
elif [[ "$choice" == "3" ]]; then
    find_scope
elif [[ "$choice" == "4" ]]; then
    delete_scope
elif [[ "$choice" == "5" ]]; then
    create_host
elif [[ "$choice" == "6" ]]; then
    delete_host
elif [[ "$choice" == "7" ]]; then
     find_host
elif [[ "$choice" == "8" ]]; then
    start_dhcp
elif [[ "$choice" == "9" ]]; then
    stop_dhcp
elif [[ "$choice" == "10" ]]; then
    restart_dhcp
elif [[ "$choice" == "11" ]]; then
    fix_SElinux
elif [[ "$choice" == "12" ]]; then
     exit 1
else
    echo "Nhập không đúng"
fi
done



