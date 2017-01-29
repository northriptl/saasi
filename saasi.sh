#!/bin/bash 

#By: Tyler Northrip
#This script configures ubuntu for optimal security
#while running TOR and tests the connection. Run using sudo
#DO NOT RUN AS ROOT!! USE SUDO

# Check for root priviliges
if [[ $EUID -ne 0 ]]; then
   printf "Please run as root:\nsudo %s\n" "${0}"
   exit 1
fi

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
    echo "$LogTime uss: [$UserName] 1. Configure sysctl" >> $LogFile

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
    echo "$LogTime uss: [$UserName] 2. Remove guest account" >> $LogFile
	#Remove the guest user by editing lightdm
	sh -c 'printf "[SeatDefaults]\nallow-guest=false\n" > /etc/lightdm/lightdm.conf.d/50-no-guest.conf'
} #End remove_guest

mac_fix(){
    echo "$LogTime uss: [$UserName] 3. Install macchanger" >> $LogFile    
    
    zenity --warning --text "For best security, select yes when the install asks"
	apt install macchanger macchanger-gtk -y 
} #End mac_fix

usb_disable(){
    echo "$LogTime uss: [$UserName] 4. Disable usb ports" >> $LogFile    
    
	echo '2-1' | tee /sys/bus/usb/drivers/usb/unbind
	echo "blacklist usb-storage" >> /etc/modprobe.d/blacklist.conf
} #End usb_disable

firewire_disable(){
    echo "$LogTime uss: [$UserName] 5. Disable firewire port(s)" >> $LogFile

	echo "blacklist firewire-ohci" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
} #End firewire_disable

firewall(){
    echo "$LogTime uss: [$UserName] 6. Configure ufw firewall" >> $LogFile    
    
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
    echo "$LogTime uss: [$UserName] 7. Remove packages" >> $LogFile

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
    FALSE " 1. Apply sysctl changes" \
    FALSE " 2. Remove guest account" \
    FALSE " 3. Install macchanger" \
    FALSE " 4. Disable usb ports" \
    FALSE " 5. Disable firewire" \
    FALSE " 6. Install/configure ufw" \
    FALSE " 7. Uninstall packages" \
    FALSE " 8. Test firewall?" \
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
            if [ "$option" -eq "1" ]  
                then
                    firewall_test | zenity --text-info --title="Firewall Test" --width 400 --height 200
                    echo "Firewall Test requested" >> $LogFile 
                fi
        #End option chain    
        fi
      
    echo "$LogTime [$UserName] * SAASI $Version - Install Log Ended" >> $LogFile
} #End gui_plus
gui_plus
