# Cấu hình DHCP Server và DHCP Relay agent bằng AutoScript
## Nội dung
- **I. Hướng dẫn chuẩn bị**
  - **1. Fix lỗi gói yum không thể sử dụng**
  - **2. Cài đặt gói DHCP để cấu hình**
  - **3. Chuẩn bị script**
    
- **II. Chạy autoscript cấu hình dhcp sever**
  - **1. Chọn card mạng và điều chình cấu hình ip tĩnh**     
  - **2. Tạo Scope**
  - **3. Kiểm tra đã cung cấp ip trên client chưa**
  - **4. Tạo host**
  - **5. Khởi động lại dịch vụ DHCP và card mạng trên máy client**
- **III. Chạy autoscript cấu hình  DHCP RELAY AGENT**
  - **1. Chọn card mạng và điều chình cấu hình ip tĩnh **     
  - **2. chạy script và tạo Scope trên máy server**
  - **3. Khởi động dịch vụ DHCP**
  - **4. chạy script reylay trên máy relay **
  - **5. Khởi động dịch vụ DHCP**
  - **6. Các bước kiểm tra host trên máy client**   


# Hướng dẫn chuẩn bị
- **1. Fix lỗi gói yum không thể sử dụng**
  - Hãy chắc chắn trên VM có thể kết nối mạng bên ngoài
  - Trên terminal chạy các lệnh dưới quyền root
  - ```C++
    sudo sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
    sudo sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
    sudo sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
    ```
  - Update lại gói yum bằng ```yum update -y``` và tiến hành ```reboot```
- **2 . Cài đặt gói DHCP để cấu hình**
  - Tiến hành cài đặt gói DHCP để cấu hình DHCP: ```yum install dhcp* -y```
- **3. Chuẩn bị script**
  - Chuẩn bị đoạn script để cấu hình dhcp với tên file được đặt là ```dhcp.sh```
    ```C+
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
          read -p "Nhập thời gian cho thuê mặc định :" lease_time
          read -p "Nhập thời gian cho thuê tối đa :" lease_time_max
        
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
    elif [[ "$choice" == "3" ]];then
        find_scope
    elif [[ "$choice" == "4" ]]; then
        delete_scope
    elif [[ "$choice" == "5" ]]; then
        create_host
    elif [[ "$choice" == "6" ]]; then
        delete_host
    elif [[ "$choice" == "8" ]]; then
        start_dhcp
    elif [[ "$choice" == "9" ]]; then
        stop_dhcp
    elif [[ "$choice" == "10" ]]; then
        restart_dhcp
    elif [[ "$choice" == "11" ]]; then
        fix_SElinux
    elif [[ "$choice" == "7" ]]; then
         find_host
    elif [[ "$choice" == "12" ]]; then
         exit 1
    else
        echo "Nhập không đúng"
    fi
    done
    ```

    
- Chuẩn bị đoạn script để cấu hình dhcp relay agent với tên file được đặt là ```relay.sh```
  

  
  ```C++
    #!/bin/bash

  cp /lib/systemd/system/dhcrelay.service /etc/systemd/system
  chmod +w /etc/systemd/system/dhcrelay.service
  
  echo "Nhập địa chỉ của DHCP Server"
  read DHCP_SERVERIP
  NEWLINE="ExecStart=/usr/sbin/dhcrelay -d --no-pid $DHCP_SERVERIP"
  sed -i "9s#.*#$NEWLINE#" /etc/systemd/system/dhcrelay.service
  
  systemctl --system daemon-reload
  systemctl start dhcrelay.service
  ```
- **II. Chạy autoscript cấu hình dhcp sever**
  - **1. Chọn card mạng và điều chình cấu hình ip tĩnh**
    -Chọn card mạng của cả 2 máy SERVER và client  là VNnet0
      ![image](https://github.com/user-attachments/assets/6e6f89ed-a4d1-4d0a-8d2f-4e3c6cbe2dcd)

    
    -Cấu hình Ip tĩnh cho máy Server với ip là ```192.168.1.1``
    ![image](https://github.com/user-attachments/assets/52db2c09-3f1b-4cea-b3e1-9c4e3aa6471b)

    
      
  - **2. chạy script và tạo Scope**
    - Yêu cầu phải cài đặt gói dhcp 
    - Yêu cầu phải chạy dưới quyền root
    - Thực hiện lệnh ``` cd Desktop``` và ``` bash dhcp.sh``` để chạy script
    - Chọn tạo scope và nhập như sau:
    - ![Screenshot 2024-10-03 115123](https://github.com/user-attachments/assets/62b3f710-ba2a-4035-a97f-cb1c30711b8c)

    - Sau đó chọn nhập 8 để chạy dịch vụ DHCP
      
      
  - **3. Kiểm tra đã cung cấp ip trên client chưa**
    -Cấu hình ip trên máy client để nhận dhcp
    ![image](https://github.com/user-attachments/assets/a07413ea-3976-4638-a2d6-d59900e02ef7)
    
    -Kiểm tra đã nhận được ip chưa
    ![Screenshot 2024-10-03 115556](https://github.com/user-attachments/assets/a67f9807-aed7-4720-9fdf-0d6d4a44bd24)

  - **4. Tạo host**
   - Tiếp tục quay lại máy server  và chọn 5 để tạo host cấu hình như sau
   - ![Screenshot 2024-10-03 115802](https://github.com/user-attachments/assets/8df41bdb-f19e-4d4c-8ed2-283f15005dd6)
     
  - **5. Khởi động lại dịch vụ DHCP và card mạng trên máy client**
   - Chọn 10 để khởi động lịch dịch vụ dhcp 
   - Xem địa chỉ Ip đã thay đổi
  - ![Screenshot 2024-10-03 115830](https://github.com/user-attachments/assets/932e38cf-6707-4564-bd23-0df0981fd1db)

- **III. Chạy autoscript cấu hình  DHCP RELAY AGENT**
  - **1. Chọn card mạng và điều chình cấu hình ip tĩnh **
     -Chọn card mạng cho máy server là VMnet1
    ![Screenshot 2024-10-03 120909](https://github.com/user-attachments/assets/53ae117c-771d-4f0e-8cbe-d354664676d5)

     -Chọn cho máy relay là 1 card mạng VMnet1 và 1 card mạng VMnet2
    ![Screenshot 2024-10-03 120923](https://github.com/user-attachments/assets/fea33db9-618f-4d5a-841d-674a27a6794e)

     -Chọn cho máy client là VMnet2 để nhận ip từ máy relay
    ![Screenshot 2024-10-03 120949](https://github.com/user-attachments/assets/0bf04574-f175-452c-abc8-8eef50adcf29)

     -Cấu hình ip tĩnh cho máy server với địa chỉ ip là ``` 192.168.1.1``` như hình sau:
     ![image](https://github.com/user-attachments/assets/52db2c09-3f1b-4cea-b3e1-9c4e3aa6471b)

     -Cấu hình ip tĩnh cho card mạng VMnet1 của máy relay là ```192.168.1.2``` như hình sau:
    
	![Screenshot 2024-10-03 122939](https://github.com/user-attachments/assets/0a927d6b-2066-4e08-81d9-f86bfb88720a)

     -Cấu hình ip tĩnh cho card mạng VMnet2 của máy relay là ```192.168.2.1``` như hình sau :
    ![Screenshot 2024-10-03 123035](https://github.com/user-attachments/assets/cc1df339-cdba-40ba-8188-abaaed8774f2)

    
  - **2. chạy script và tạo Scope trên máy server**
     - Yêu cầu phải cài đặt gói dhcp
     - Yêu cầu phải chạy dưới quyền root
     - Thực hiện lệnh ``` cd Desktop``` và ``` bash dhcp.sh``` để chạy script
     - Chọn tạo scope và nhập như sau:
      	- 1 Scope mang subnet là ```192.168.1.0```
      	![Screenshot 2024-10-03 122433](https://github.com/user-attachments/assets/87004c96-6a86-4093-9a5b-985e78dd6afa)

         
     	- 1 Scope mang subnet là ```192.168.2.0```
   	
        ![Screenshot 2024-10-03 122610](https://github.com/user-attachments/assets/314a9e08-f388-4c5f-8990-da498bcccece)

	- Sau đó chọn 8 để khởi động dịch vụ dhcp
  - **4. chạy script reylay trên máy relay **
     - Yêu cầu phải cài đặt gói dhcp
     - Yêu cầu phải chạy dưới quyền root
     - Thực hiện lệnh ``` cd Desktop``` và ``` bash relay.sh``` để chạy script
     - Và nhập địa chỉ ip của máy server ```192.168.1.1``` như hình:
       
     - ![Screenshot 2024-10-03 123127](https://github.com/user-attachments/assets/71d0e2f2-f8b9-4ac6-9c73-73de1a734da6)

       

  - **5. Kiểm tra trên máy client đã nhận ip chưa**
    -Cấu hình ip trên máy client để nhận dhcp
    
    ![image](https://github.com/user-attachments/assets/a07413ea-3976-4638-a2d6-d59900e02ef7)
    
    -Kiểm tra đã nhận được ip cấp phát đúng mong đợi
    
    ![Screenshot 2024-10-03 123250](https://github.com/user-attachments/assets/3abbc71c-530a-4a12-8e7f-8ff4bdf65a9b)


Người thực hiện: Trần Gia Bảo và Nguyễn Minh Hậu



    
  
