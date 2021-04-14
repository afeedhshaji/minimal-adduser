DESCRIPTION
------------
A user interactive minimal implementation of the adduser/useradd command in linux written
as part of the Computer Security course at NIT Calicut. It basically prompts for a username
and password and creates the shadow type password hash and adds the userinfo to the /etc/passwd 
and the hashed password to the /etc/shadow file. 


USAGE
------
** Warning : The script can only be run as a root user. Use at your own risk! **

Run this command in a root shell
- wget -O - https://raw.githubusercontent.com/afeedh/minimal-adduser/master/adduser.sh | bash
