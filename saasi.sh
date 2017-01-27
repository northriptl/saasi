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

#DO NOT TOUCH THIS CODE
#CONTAINS MAGIC
greeter(){  
read -d '' help <<- EOF
. _____                    _____ _____ 
 / ____|  /\\\        /\\\    / ____|_   _|
| (___   /  \\\      /  \\\  | (___   | |  
 \\\___ \\\ / /\\\ \\\    / /\\\ \\\  \\\___ \\\  | |  
 ____) / ____ \\\  / ____ \\\ ____) |_| |_ 
|_____/_/    \\\_\\\/_/    \\\_\\\_____/|_____|
"Script Aimed At Securing Installs"

Dev: Tyler Northrip
Version: 0.1                   
EOF

echo "$help" 
}

sysctl(){
#Kernel network security settings
/sbin/sysctl -w net.ipv4.conf.default.rp_filter=1 
/sbin/sysctl -w net.ipv4.conf.all.rp_filter=1 
/sbin/sysctl -w net.ipv4.tcp_syncookies=1 
/sbin/sysctl -w net.ipv4.conf.all.accept_redirects=0 
/sbin/sysctl -w net.ipv6.conf.all.accept_redirects=0 
/sbin/sysctl -w net.ipv4.conf.all.send_redirects=0 
/sbin/sysctl -w net.ipv4.conf.all.accept_source_route=0 
/sbin/sysctl -w net.ipv6.conf.all.accept_source_route=0 
/sbin/sysctl -w net.ipv4.conf.all.log_martians=1

sh -c 'printf "kernel.kptr_restrict=1\nkernel.yama.ptrace_scope=1\nvm.mmap_min_addr=65536" > /etc/sysctl.conf'
sh -c 'printf "net.ipv4.icmp_echo_ignore_broadcasts=1\nnet.ipv4.icmp_ignore_bogus_error_responses=1\nnet.ipv4.icmp_echo_ignore_all=0" > /etc/sysctl.conf'

#reload sysctl
sysctl -p
} #End sysctl

remove_guest(){
#Remove the guest user by editing lightdm
sh -c 'printf "[SeatDefaults]\nallow-guest=false\n" > /etc/lightdm/lightdm.conf.d/50-no-guest.conf'
} #End remove_guest

firewall(){
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

packages(){
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

main(){
	greeter
	
	#Main functions
	printf "\nThe program will now do general security fixes\n"
	printf "Press enter to continue"
	read continue
	
	#sysctl
	firewall
	remove_guest
	
	#Ask to do firewall test
	while true 
		do
    		read -p "\nDo you wish to perform a simple firewall test? y/n: " yn
    		case $yn in
        		[Yy]* ) printf "\n"; firewall_test; break;;
        		[Nn]* ) break;;
        		* ) echo "Please answer yes or no.";;
    		esac
	done
	
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
	
	
	printf "\nScript exiting\nIt is strongly recommended to reboot after running this script\n"
	
} #End main

main
