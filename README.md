# emailserver

Dokcer all-in-one email server modified from Hardware/mailserver (Copyright (c) 2016 Hardware <contact@meshup.net>)

It is my personal all-in-one email docker server project for my own use.
The base of project is Hardware/mailserver (https://github.com/hardware/mailserver), so all credit shoud go to him.

Anybody can use and modify it with his own risk, but there is neither warranty nor support including question.

ports:
 - "25:25" SMTP - Required
 - "110:110" POP3 - Optional
 - "143:143" IMAP - Optional
 - "465:465" SMTPS - Optional
 - "587:587" Submission - Optional
 - "993:993" IMAPS - Optional
 - "995:995" POP3S - Optional
 - "4190:4190" SIEVE - Optional
 - "4191:3306" MARIADB - Optional
 - "8081:8081" RAINLOOP - Optional
 - "8082:11334" RSPAMD WEB - Optional
 - "8083:8083" POSTFIXADMIN - Optional
 - "8084:8084" PHPMYADMIN - Optional
 
For the Hardware/mailserver license rule, the following is his License including his copyright notice.
------------------------------------------------------------------------------
The MIT License (MIT)

Copyright (c) 2016 Hardware <contact@meshup.net>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
