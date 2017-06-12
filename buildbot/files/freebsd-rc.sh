#! /bin/sh
# {{ fullname }}
# Maintainer: @tim
# Authors: @tim

# PROVIDE: {{ fullname }}
# REQUIRE: LOGIN
# KEYWORD: shutdown

. /etc/rc.subr

name="{{ fullname }}"
rcvar="{{ fullname }}_enable"

load_rc_config {{ fullname }}

: ${{ '{' }}{{ fullname }}_enable:="NO"}
: ${{ '{' }}{{ fullname }}_user:="{{ user }}"}

required_dirs={{ directory }}

pidfile={{ directory }}/daemon.pid
procname={{ virtualenv }}/bin/{{ executable }}
command=/usr/sbin/daemon
command_interpreter={{ virtualenv }}/bin/python2.7
command_args="-p ${pidfile} -f ${procname} start --nodaemon"

start_precmd="buildbot_precmd"

buildbot_precmd()
{
    install -o {{ user }} /dev/null ${pidfile}

    export PATH="${PATH}:/usr/local/bin:/usr/local/sbin"
    cd {{ directory }}
}

run_rc_command "$1"
