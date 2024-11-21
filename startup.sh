#!/bin/sh

/.config/startup/init_app.sh

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
