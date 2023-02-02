# APPS - Automatic Pi Picoprobe Setup
Raspberry pi pico probe setup as well as pi pico setup for Linux (tested with linux mint and ubuntu)

## Setup 
1. Install git ``sudo apt install git`` and make sure git is configured   
   ``git config --global user.name "Your Name"``  
   ``git config --global user.email "youremail@yourdomain.com"``
2. Clone this github repository using 
  ``git clone https://github.com/alexandersep/pico-probe``
3. Enter folder ``cd pico-probe``
4. Give yourself executable privileges ``chmod +x pico_setup.sh``
5. Run **APPS** ``./apps.sh``
6. If installation successfull a restart may be required, if unsuccessfull, **APPS**
   gives error messages for backtracking and fixing issues.

## Common Errors
* If you encounter an error with picoprobe failing a cmake, you're SDK\_PICO\_PATH is
  configured incorrectly. cmake sees one directory and your the path that was appended 
  in ~/.bashrc sees the other. Fix paths, try and cmake again, it should resolve once
  paths are all matching
* You must not name a directory "pico". It is recommended to clone and run the script in
  home/$USER/ Documents/ directory 

## Based on
``https://raw.githubusercontent.com/raspberrypi/pico-setup/master/pico_setup.sh``  
A lot of changes were used to get it working for the CSU23021-202122 (MICROPROCESSOR SYSTEMS) module
as well as quality of life improvements such as error checking and fixes
