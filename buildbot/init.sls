{% from 'buildbot/map.jinja' import buildbot with context %}
{% from 'buildbot/macros.jinja' import sls_block, labels with context %}

{% for pkg in buildbot.packages %}
{{ pkg }}:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}

buildbot_venv:
  virtualenv.managed:
    - name: {{ buildbot.virtualenv.directory }}

{% set deps = [] %}
buildbot_git:
  git.latest:
    - name: {{ buildbot.source.url }}
    - target: {{ buildbot.source.checkout }}
    - rev: {{ buildbot.source.revision }}
    - branch: {{ buildbot.source.branch }}
    - force_reset: True

{% for dir in buildbot.source.components %}
buildbot_pip_{{ dir }}:
  pip.installed:
    - name: {{ buildbot.source.checkout }}/{{ dir }}
    - bin_env: {{ buildbot.virtualenv.directory }}
    - require:
      - git: buildbot_git
      - virtualenv: buildbot_venv
{% do deps.append('pip: buildbot_pip_' + dir) %}
{% endfor %}

{% for master in buildbot.masters %}
{% set root = master.get('root', '/home/' + master.user + '/' + master.name) %}
buildbot_{{ master.name }}_user:
  user.present:
    - name: {{ master.user }}

buildbot_{{ master.name }}_group:
  group.present:
    - name: {{ master.group }}

buildbot_{{ master.name }}_root:
  file.directory:
    - name: {{ root }}
    - user: {{ master.user }}
    - group: {{ master.group }}
    - makedirs: true

buildbot_{{ master.name }}_config:
  git.latest:
    - name: {{ master.config_url }}
    - target: {{ root }}
    - user: {{ master.user }}
    - rev: master
    - branch: master
    - force_reset: True

buildbot_{{ master.name }}_create:
  cmd.run:
    - name: '. {{ buildbot.virtualenv.directory }}/bin/activate && buildbot create-master'
    - cwd: {{ root }}
    - runas: {{ master.user }}
    - creates: '{{ root }}/buildbot.tac'

buildbot_{{ master.name }}_upgrade:
  cmd.run:
    - name: '. {{ buildbot.virtualenv.directory }}/bin/activate && buildbot upgrade-master'
    - cwd: {{ root }}
    - runas: {{ master.user }}
    - creates: '{{ root }}/buildbot.tac'
    - onchanges:
      - git: buildbot_{{ master.name }}_config
      {{ labels(deps) | indent(6) }}
{% endfor %}

{% for slave in buildbot.slaves %}
{% set root = slave.get('root', '/home/' + slave.user + '/' + slave.name) %}
buildslave_{{ slave.name }}_user:
  user.present:
    - name: {{ slave.user }}

buildslave_{{ slave.name }}_group:
  group.present:
    - name: {{ slave.group }}

buildslave_{{ slave.name }}_root:
  file.directory:
    - name: {{ root }}
    - user: {{ slave.user }}
    - group: {{ slave.group }}
    - makedirs: true

buildslave_{{ slave.name }}_create:
  cmd.run:
    - name: '. {{ buildbot.virtualenv.directory }}/bin/activate && buildslave create-slave {{ root }} {{ slave.master }} {{ slave.name }} {{ slave.password }}'
    - cwd: {{ root }}
    - runas: {{ slave.user }}
    - creates: '{{ root }}/buildbot.tac'

buildslave_{{ slave.name }}_admin:
  file.managed:
    - name: {{ root }}/info/admin
    - user: {{ slave.user }}
    - group: {{ slave.group }}
    {{ sls_block(slave.admin) | indent(4) }}

buildslave_{{ slave.name }}_host:
  file.managed:
    - name: {{ root }}/info/host
    - user: {{ slave.user }}
    - group: {{ slave.group }}
    {{ sls_block(slave.host) | indent(4) }}
{% endfor %}