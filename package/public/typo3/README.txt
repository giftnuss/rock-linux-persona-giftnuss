Installation directory
--------------------------------------------

Basically, the destination directory is location independant,
besides that the symbolic links to the typo3_src dir are fixed.

Install the respective package you have choosen (testsite, quickstart
or dummy), located in the Apache lib directory (usually /var/opt/apache/lib)
into you htdocs directory.

Example: 
cp -avP /var/opt/apache/lib/typo3-quickstart /var/opt/apache/lib/htdocs/typo3

Prerequisites
--------------------------------------------

MySQL

If you haven't setup mysql yet, it's now time to execute the following commands
and start mysql afterwards:

/opt/mysql/bin/mysql_install_db

/opt/mysql/bin/mysqladmin -u root password 'new-password'
/opt/mysql/bin/mysqladmin -u root -h data password 'new-password'

After being connected to mysql, issue the following commands to create
a typo3 user:

grant all privileges on typo3.* TO 'typo3' identified by 'new-password';
flush privileges;

[...]

Typo3 Installation Password
--------------------------------------------

The following paths given are relative to the document root
(see httpd.conf: DocumentRoot).

Before first usage of the typo3 installation tool, you have to
set two passwords, the first one resides in typo3conf/localconf.php
and the second one is in typo3/typo3/install/.htpasswd. In the latter
case you may alternatively modify the respective 
typo3/typo3/install/.htaccess file.

Creating the password in typo3conf/localconf.php is done with
# echo -n "password" | md5sum

Creating the password in typo3/typo3/install/.htpasswd is done with
# touch typo3/typo3/install/.htpasswd
# htpasswd -b typo3/typo3/install/.htpasswd username password

Remove the die() call from 
typo3/typo3/install/index.php

Finally start your browser with
http://localhost/typo3/typo3/install/
