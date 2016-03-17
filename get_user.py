#!/bin/python
from subprocess import Popen, PIPE
import sys
users=( Popen(['/bin/sh', '-c',
			"mysql -h10.1.1.49 -u " + sys.argv[1] + " -p" + sys.argv[2] + " -Be 'use mysql;select * from user;'"
			], stdout=PIPE) )
index=0
mysql_users=[]

for i in iter(users.stdout.readline, b''):
	if index == 0:
		i=i.replace("\n",'')
		i=i.replace("\n",'')
		i = i.replace( "\t", ",")
		headers = i
		index+=1
	else:
		if 'root' in i or 'debian-sys-maint' in i:
			continue
		i = i.replace( "\t", "','")
		i = "'" + i + "'"
		mysql_users+=[i]
sql = "INSERT INTO mysql.user (" + headers + ") VALUES "
index = 0
for row in mysql_users:
	if index == 0:
		sql += "(" + row + ")"
		index += 1
	else:
		sql += ",(" + row + ")"
sql += ";"
file = open("/tmp/users.sql", "w")
file.write(sql)
file.close()