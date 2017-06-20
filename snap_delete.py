#!/bin/python
#Is ran by cron job every sunday at 4:12 am after weekly backup is ran
# crontab -e
# 12 4 * * 7 python /path/to/snap_delete.py

import subprocess
import json
import datetime
import smtplib
import socket
try:
	from email.mime.text import MIMEText
except ImportError:
    # Python 2.4 (CentOS 5.x)
    from email.MIMEText import MIMEText
    
# Change this to some value if you don't want your server hostname to show in
# the notification emails
THIS_SERVER = socket.gethostname()

# Server hostname or IP address
SMTP_SERVER = 'yourdomain.com.mail.protection.outlook.com'
SMTP_PORT = 25

# Set to True if you need SMTP over SSL
SMTP_SSL = False

# Set to True if you need to authenticate to your SMTP server
SMTP_AUTH = False
# Fill in authorization information here if True above
SMTP_USERNAME = 'stuartz@yourdomain.com'
SMTP_PASSWORD = ''

# Takes a single sender
MAIL_FROM = 'stuartz@yourdomain.com'
# Takes a list of recipients
MAIL_TO = ['stuartz@yourdomain.com']

# Need Date in Header for SMTP RFC Compliance
DATE = datetime.datetime.now().strftime( "%m/%d/%Y %H:%M" )

#snapshot management variables
weeklys = []
dailys = []
dt7daysago = datetime.datetime.now() - datetime.timedelta(days=7)
dtmntago = datetime.datetime.now() - datetime.timedelta(days=28)


def get_snapshots(period, date2check):
	pipe = subprocess.Popen(["aws ec2 describe-snapshots --filters Name=tag-key,Values='backup' Name=tag-value,Values='"+period+"' --query 'Snapshots[*].{ID:SnapshotId,Time:StartTime}'"],
						stdout=subprocess.PIPE, shell=True)
	jsonstr = ''
	# convert string to json
	for row in pipe.stdout:
		jsonstr += row
	try:
		x = json.loads(jsonstr)
	except:
		return "json load failed in snap_delete.py"
	for row in x:
		try:
			print row['Time'][:10]
			if datetime.datetime.strptime(row['Time'][:10], "%Y-%m-%d")< date2check:
				weeklys.append(row['ID'])
		except:
			return "snapshot check failed in snap_delete.py"
	snapshot_count = 0
	for id in weeklys:
		subprocess.Popen(["aws ec2 delete-snapshot --snapshot-id "+ id], stdout=subprocess.PIPE, shell=True)
		print id + " has been deleted"
		snapshot_count += 1
	return period + " snapshots have been successfully deleted.  Count=" + str(snapshot_count)

def send_notification(from_email, to_email, subject, date, message, smtp_server,
                      smtp_port, use_ssl, use_auth, smtp_user, smtp_pass):
    msg = MIMEText(message)

    msg['From'] = from_email
    msg['To'] = ', '.join(to_email)
    msg['Subject'] =  subject
    msg['Date'] =  date

    if(use_ssl):
        mailer = smtplib.SMTP_SSL(smtp_server, smtp_port)
    else:
        mailer = smtplib.SMTP(smtp_server, smtp_port)

    if(use_auth):
        mailer.login(smtp_user, smtp_pass)

    mailer.sendmail(from_email, to_email, msg.as_string())
    mailer.close()

#delete daily snapshots older than 7 days
msg = get_snapshots("daily", dt7daysago)
try:
	send_notification(MAIL_FROM, MAIL_TO, 'Galera Notification: ' + THIS_SERVER, DATE,
					  str(msg), SMTP_SERVER, SMTP_PORT, SMTP_SSL, SMTP_AUTH,
					  SMTP_USERNAME, SMTP_PASSWORD)
except Exception, e:
	print "Unable to send notification: %s" % e
	sys.exit(1)

#delete weekly snapshots older than 28 days
msg = get_snapshots("weekly", dtmntago)
try:
	send_notification(MAIL_FROM, MAIL_TO, 'Galera Notification: ' + THIS_SERVER, DATE,
					  str(msg), SMTP_SERVER, SMTP_PORT, SMTP_SSL, SMTP_AUTH,
					  SMTP_USERNAME, SMTP_PASSWORD)
except Exception, e:
	print "Unable to send notification: %s" % e
	sys.exit(1)
# get weelkys that are older than 28 days and delete
