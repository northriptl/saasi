#!/bin/bash 

#By: Tyler Northrip
#This script configures ubuntu for optimal security
#while running TOR and tests the connection. Run using sudo
#DO NOT RUN AS ROOT!! USE SUDO

Version="v0.2 alpha"
UserName=$(whoami)
LogDay=$(date '+%Y-%m-%d')
LogTime=$(date '+%Y-%m-%d %H:%M:%S')
LogFile=/var/log/saasi_$LogDay.log

#DO NOT TOUCH THIS CODE
#CONTAINS MAGIC
greeter(){  
	read -d '' help <<- EOF
	. _____                    _____ _____ 
	 / ____|  /\\\        /\\\    / ____|_   _|
	 |(___   /  \\\      /  \\\  | (___   | |  
	 \\\___ \\\ / /\\\ \\\    / /\\\ \\\  \\\___ \\\  | |  
	 ____) / ____ \\\  / ____ \\\ ____) |_| |_ 
	|_____/_/    \\\_\\\/_/    \\\_\\\_____/|_____|
	"Script Aimed At Securing Installs"

	Dev: Tyler Northrip
	Version: 0.1                   
	EOF

	echo "$help" 
}

sysctl_fixes(){
    echo "$LogTime uss: [$UserName] 1. Configure sysctl"

	#Kernel network security settings
	sysctl -w net.ipv4.conf.default.rp_filter=1 
	sysctl -w net.ipv4.conf.all.rp_filter=1 
	sysctl -w net.ipv4.tcp_syncookies=1 
	sysctl -w net.ipv4.conf.all.accept_redirects=0 
	sysctl -w net.ipv6.conf.all.accept_redirects=0 
	sysctl -w net.ipv4.conf.all.send_redirects=0 
	sysctl -w net.ipv4.conf.all.accept_source_route=0 
	sysctl -w net.ipv6.conf.all.accept_source_route=0 
	sysctl -w net.ipv4.conf.all.log_martians=1

	#sh -c 'printf "kernel.kptr_restrict=1\nkernel.yama.ptrace_scope=1\nvm.mmap_min_addr=65536" > /etc/sysctl.conf'
	#sh -c 'printf "net.ipv4.icmp_echo_ignore_broadcasts=1\nnet.ipv4.icmp_ignore_bogus_error_responses=1\nnet.ipv4.icmp_echo_ignore_all=0" > /etc/sysctl.conf'
} #End sysctl

remove_guest(){
    echo "$LogTime uss: [$UserName] 2. Remove guest account" 
	#Remove the guest user by editing lightdm
	sh -c 'printf "[SeatDefaults]\nallow-guest=false\n" > /etc/lightdm/lightdm.conf.d/50-no-guest.conf'
} #End remove_guest

mac_fix(){
    echo "$LogTime uss: [$UserName] 3. Install macchanger"    
    
    zenity --warning --text "For best security, select yes when the install asks"
	apt install macchanger macchanger-gtk -y 
} #End mac_fix

usb_disable(){
    echo "$LogTime uss: [$UserName] 4. Disable usb ports"     
    
	echo '2-1' | tee /sys/bus/usb/drivers/usb/unbind
	echo "blacklist usb-storage" >> /etc/modprobe.d/blacklist.conf
} #End usb_disable

firewire_disable(){
    echo "$LogTime uss: [$UserName] 5. Disable firewire port(s)" 

	echo "blacklist firewire-ohci" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
} #End firewire_disable

firewall(){
    echo "$LogTime uss: [$UserName] 6. Configure ufw firewall"     
    
	#Reset the ufw config
	ufw --force reset

	#Deny all incoming traffic and outgoing traffic
	ufw default deny incoming
	ufw default deny outgoing

	#Allow out HTTP traffic (unencrypted web pages)
	ufw allow out 80/tcp
	ufw allow out 80/udp

	#Allow out HTTPS traffic (encrypted web pages)
	ufw allow out 443/tcp
	ufw allow out 443/udp

	#Allow out dns, neccesary for the connection test to succeed. TOR does NOT need dns to function
	ufw allow out 53/tcp
	ufw allow out 53/udp

	#If you need to download a file using ftp, copy the
	#following lines into a terminal
	#sudo ufw allow out 20,21/tcp
	#Sudo ufw allow out 20,21/udp

	#The below code backs up the old before.rules and copies the modified one over
	{ 
		cp /etc/ufw/before.rules /etc/ufw/before.rules.old && cp ./before.rules /etc/ufw/before.rules
	} ||
	{ 
		printf "Please make sure that before.rules is in the same folder as this script\n"
	}

	#Reload the firewall
	ufw disable
	ufw enable

} #End Firewall

packages(){
    echo "$LogTime uss: [$UserName] 7. Remove packages"

	#Remove packages to improve security and shrink attack surface
	#Firefox is not needed. TOR should be the only browser
	#gcc g++ are removed to prevent code being compiled locally
	#Cheese is removed to prevent easy access to webcam
	#Yelp, Thunderbird, cups, yelp removed to reduce attack surface
	#Vino removed since it is remote access software
	#ftp, rsync, ssh, wget, curl removed to prevent easy downloading of files
	apt -qq remove firefox vino yelp gcc g++ cheese thunderbird cups ftp rsync ssh wget curl -y
	apt -qq autoremove -y

} #End packages

install_rkhunter(){
    echo "$LogTime uss: [$UserName] 8. Configure rkhunter" >> $LogFile
    apt install -qq rkhunter -y >> $LogFile | zenity --progress --title="RKHunter - SAASI $Version" --text="Downloading updates..." --width 400 --auto-close --percentage=25
    rkhunter --update 2>&1 >> $LogFile | zenity --progress --title="RKHunter - SAASI $Version" --text="Downloading updates..." --width 400 --auto-close --percentage=50
    rkhunter --propupd 2>&1 >> $LogFile | zenity --progress --title="RKHunter - SAASI $Version" --text="Updating properties..." --width 400 --auto-close --percentage=75
    
    zenity --question --title "RKHunter - SAASI $Version" --text "Would you like to run a RKHunter check now?"
        if [ "$?" -eq "0" ]
            then
        	    # Run RKHunter check and output to Zenity         
                sudo rkhunter --check --nocolors --skip-keypress 2>&1 | zenity --text-info --title "RKHunter - SAASI $Version" --width 600 --height 400
                echo "# RKHunter check done"
                echo "$LogTime uss: [$UserName] RKHunter check done"      
            fi
} #End install_rkhunter

secure_fstab(){
            echo "$LogTime uss: [$UserName] Check if shared memory is secured" >> $LogFile          
            # Make sure fstab does not already contain a tmpfs reference
            fstab=$(grep -c "tmpfs" /etc/fstab)
            if [ ! "$fstab" -eq "0" ] 
              then
                 echo "$LogTime uss: [$UserName] fstab already contains a tmpfs partition." >> $LogFile
            fi
            if [ "$fstab" -eq "0" ]
              then
                 echo "$LogTime uss: [$UserName] fstab being updated to secure shared memory" >> $LogFile
                 sudo echo "# $TFCName Script Entry - Secure Shared Memory - $LogTime" >> /etc/fstab
                 sudo echo "tmpfs     /dev/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab
                 echo "$LogTime uss: [$UserName] Shared memory secured. Reboot required" >> $LogFile
      	    fi
  		
} #End secure_fstab

firewall_test(){
	#The below code attempts to connect to a webpage via ports 80,81
	#if the attempt fails, the print statement is executed. If the firewall
	#is functioning as configure, only the second print statement should execute
	{ 
		wget -qO- --tries=1 --timeout=5 portquiz.net:80 
	} || 
	{ 
		printf "Please check your connection, port 80 failed\n"
	}

	{ 
		wget -qO- --tries=1 --timeout=5 portquiz.net:81
	} || 
	{ 
		printf "Port 81 is blocked, firewall is functioning\n"
	}

} #End firewall_test

terminal_only(){
	greeter
	
	#Main functions
	printf "\nThe program will now do general security fixes\n"
	printf "Press enter to continue"
	read continue
	
	sysctl_fixes
	firewall
	remove_guest
	
	printf "\n"
	#Ask to do firewall test
	while true 
		do
    		read -p "Do you wish to perform a simple firewall test? y/n: " yn
    		case $yn in
        		[Yy]* ) printf "\n"; firewall_test; break;;
        		[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
    		esac
	done
	
	printf "\n"
	#Ask to remove packages
	while true 
		do
    		read -p "Do you wish to remove unneeded/dangerous packages? y/n: " yn
    		case $yn in
        		[Yy]* ) packages; break;;
        		[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
    		esac
	done
	
	printf "\n"
	#Ask to install macchanger
	while true 
		do
    		read -p "Would you like to install macchanger (recommended)? y/n: " yn
    		case $yn in
        		[Yy]* ) printf "\n"; mac_fix; break;;
        		[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
    		esac
	done
	
	printf "\n"
	#Ask to install macchanger
	while true 
		do
    		read -p "Would you like to disable all usb ports (recommended only for VM)? y/n: " yn
    		case $yn in
        		[Yy]* ) printf "\n"; usb_disable; break;;
        		[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
    		esac
	done
	
	printf "\n"
	#Ask to install macchanger
	while true 
		do
    		read -p "Would you like to disable firewire? y/n: " yn
    		case $yn in
        		[Yy]* ) printf "\n"; firewire_disable; break;;
        		[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
    		esac
	done
	
	printf "\nScript exiting\nIt is strongly recommended to reboot after running this script\n"
	
} #End terminal_only

gui_plus(){
    response=$(zenity --list --checklist --title="SAASI $Version" --column=Boxes --column=Selections --text="Select the security features you want" --width 480 --height 550 \
    TRUE " 1. Apply sysctl changes" \
    TRUE " 2. Remove guest account" \
    TRUE " 3. Install macchanger" \
    FALSE " 4. Disable usb ports" \
    FALSE " 5. Disable firewire" \
    TRUE " 6. Install/configure ufw" \
    TRUE " 7. Uninstall packages" \
    TRUE " 8. Install rkhunter" \
    TRUE " 9. Secure shared memory" \
    TRUE "10. Test firewall?" \
    --separator=':')

    if [ -z "$response" ] ; then
       echo "No selection"
       exit 1
    fi

    if [ ! "$response" = "" ] 
      then
        echo "$LogTime [$UserName] * SAASI $Version - Install Log Started" >> $LogFile
        
        option=$(echo $response | grep -c "1.")
            if [ "$option" -eq "1" ]  
                then
                    sysctl_fixes >> $LogFile
                fi
            
            
        option=$(echo $response | grep -c "2.")
            if [ "$option" -eq "1" ]  
                then
                    remove_guest >> $LogFile
                fi
            
        
        option=$(echo $response | grep -c "3.")
            if [ "$option" -eq "1" ]  
                then
                    mac_fix >> $LogFile
                fi
                    
            
        option=$(echo $response | grep -c "4.")
            if [ "$option" -eq "1" ]  
                then
                    usb_disable >> $LogFile
                fi
            
            
        option=$(echo $response | grep -c "5.")
            if [ "$option" -eq "1" ]  
                then
                    firewire_disable >> $LogFile
                fi
            
        
        option=$(echo $response | grep -c "6.")
            if [ "$option" -eq "1" ]  
                then
                    firewall >> $LogFile
                fi
            
            
        option=$(echo $response | grep -c "7.")
            if [ "$option" -eq "1" ]  
                then
                    packages >> $LogFile
                fi
        option=$(echo $response | grep -c "8.")
	    if [ "$option" -eq "1"]
	    	then
		    #logging done inside function
		    install_rkhunter
            	fi
		
	option=$(echo $response | grep -c "9.")
	    if [ "$option" -eq "1"]
	    	then
		    #logging done inside function
		    secure_fstab
            	fi
		
        option=$(echo $response | grep -c "10.")
            if [ "$option" -eq "1" ]  
                then
                    firewall_test | zenity --text-info --title="Firewall Test" --width 400 --height 200
                    echo "Firewall Test requested" >> $LogFile 
                fi
        #End option chain    
        fi
      
    echo "$LogTime [$UserName] * SAASI $Version - Install Log Ended" >> $LogFile
} #End gui_plus

# Check for root priviliges
if [[ $EUID -ne 0 ]]; then
   printf "Please run as root:\nsudo bash %s\n" "${0}"
   exit 1
fi

while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo "SAASI - Script Aimed At Securing Installs"
                        echo " "
                        echo "usage:"
                        echo "-h, --help                show brief help"
                        echo "-terminal                 runs text only (not up to date)"
			echo "-gui                      runs with gui (recommended)"
                        exit 0
                        ;;
                -terminal)
                        shift
                        terminal_only    
                        shift
                        ;;
                -gui)
                        shift
                        gui_plus   
                        shift
                        ;;
                *)
                        echo "SAASI - Script Aimed At Securing Installs"
                        echo " "
                        echo "usage:"
                        echo "-h, --help                show brief help"
                        echo "-terminal                 runs text only (not up to date)"
			echo "-gui                      runs with gui (recommended)"
                        exit 0
                        ;;
        esac
done
