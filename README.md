# SAASI

Script Aimed At Securing Installs

The goal of this script is to secure debian based virtual machines for TOR usage.

# Installation

## Requirements

* wget
* sudo privileges

## Using Git (recommended method)

I recommend using git because I have included additional files in this repo that are required for some of the functions of this script. 

    git clone https://github.com/northriptl/saasi
    cd saasi
    sudo bash saasi.sh -gui
  
## Direct Method

Most of the script will still work, but some of the extra features of ufw will not be implemented without before.rules being downloaded too.

    wget https://raw.githubusercontent.com/northriptl/saasi/master/saasi.sh
    sudo bash saasi.sh -gui
  
# Best Practices

The best way to use this script it to create a new vm and install ubuntu from iso. Then update and upgrade the install, then use saasi for added security.
  
  
# How to Update

    cd saasi
    git pull
    
# Why

I made this to make it easier to secure a new linux installation. Some people may wish to use TOR or other dark web protocols and wish to have a secure machine. 
    
# License

The saasi script is under a MIT license because I can.
Please see [LICENSE](LICENSE) for more details.
