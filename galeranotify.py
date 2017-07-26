#!/usr/bin/python
#
# Script to send email notifications when a change in Galera cluster membership
# occurs.
#
# Complies with http://www.codership.com/wiki/doku.php?id=notification_command
#
# Author: Gabe Guillen <gguillen@gesa.com>
# Modified by: Josh Goldsmith <joshin@hotmail.com>
# Modified by: Stuart Zurcher
# Version: 1.5
# Release: 6/20/17
# Use at your own risk.  No warranties expressed or implied.
#

import os
import sys
import argparse
from subprocess import Popen, PIPE

import datetime

try: from email.mime.text import MIMEText
except ImportError:
    # Python 2.4 (CentOS 5.x)
    from email.MIMEText import MIMEText

import socket

# Change this to some value if you don't want your server hostname to show in
# the notification emails
THIS_SERVER = socket.gethostname()
# Takes a single sender
HOST = os.getenv('HOSTNAME')
MAIL_FROM = os.getenv('MAIL_FROM','noreply@'+HOST)
# Takes a list of recipients
MAIL_TO = [os.getenv('MAIL_TO','root')]


# Need Date in Header for SMTP RFC Compliance
DATE = datetime.datetime.now().strftime( "%m/%d/%Y %H:%M" )

# Edit below at your own risk
################################################################################
def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('--status', type=str)
    parser.add_argument('--primary', type=str)
    parser.add_argument('--members', nargs='*')
    parser.add_argument('--index', type=str)
    parser.add_argument('--uuid', type=str)

    usage = "Usage: " + os.path.basename(sys.argv[0]) + " --status <status str>"
    usage += " --primary <yes/no> --members <comma-seperated"
    usage += " list of the component member UUIDs> --index <n>"
    args = parser.parse_args()
    if(len(vars(args)) > 0):
        message_obj = GaleraStatus(THIS_SERVER)
        for opt in vars(args):
            if opt == '-h':
                print(usage)
                sys.exit()
            elif opt in ("--status"):
                message_obj.set_status(getattr(args,opt))
            elif opt in ("--primary"):
                message_obj.set_primary(getattr(args,opt))
            elif opt in ("--members"):
                message_obj.set_members(getattr(args,opt))
            elif opt in ("--index"):
                message_obj.set_index(getattr(args,opt))

        try:
            send_notification(MAIL_FROM, MAIL_TO, 'Galera Notification: ' + THIS_SERVER, DATE,
                              str(message_obj))
        except Exception as e:
            print("Unable to send notification: %s" % e)
            sys.exit(1)
    else:
        print(usage)
        sys.exit(2)

    sys.exit(0)

def send_notification(from_email, to_email, subject, date, message):
    msg = MIMEText(message)

    msg['From'] = from_email
    msg['To'] = ', '.join(to_email)
    msg['Subject'] =  subject
    msg['Date'] =  date
    p = Popen(["/usr/sbin/sendmail", "-t", "-oi"], stdin=PIPE, universal_newlines=True)
    p.communicate(msg.as_string())

class GaleraStatus:
    def __init__(self, server):
        self._server = server
        self._status = ""
        self._uuid = ""
        self._primary = ""
        self._members = ""
        self._index = ""
        self._count = 0

    def set_status(self, status):
        self._status = status
        self._count += 1

    def set_primary(self, primary):
        if primary:
            self._primary = primary.capitalize()
            self._count += 1

    def set_members(self, members):
        self._members = members
        self._count += 1

    def set_index(self, index):
        self._index = index
        self._count += 1

    def __str__(self):
        message = "Galera running on " + self._server + " has reported the following"
        message += " cluster membership change"

        if(self._count > 1):
            message += "s"

        message += ":\n\n"

        if(self._status):
            message += "Status of this node: " + self._status + "\n\n"

        if(self._primary):
            message += "Current cluster component is primary: " + self._primary + "\n\n"

        if(self._members):
            message += "Current members of the component:\n"

            if(self._index):
                for i in range(len(self._members)):
                    if(i == int(self._index)):
                        message += "-> "
                    else:
                        message += "-- "

                    message += self._members[i] + "\n"
            else:
                message += "\n".join(("  " + str(x)) for x in self._members)

            message += "\n"

        if(self._index):
            message += "Index of this node in the member list: " + self._index + "\n"

        return message

if __name__ == "__main__":
    main(sys.argv[1:])
