{% from 'buildbot/map.jinja' import buildbot with context %}
{% from 'buildbot/macros.jinja' import sls_block, labels with context %}

{% for pkg in buildbot.packages %}
buildbot_{{ pkg }}:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}

buildbot_venv:
  virtualenv.managed:
    - name: {{ buildbot.virtualenv.directory }}
    - venv_bin: {{ buildbot.virtualenv.bin }}

buildbot_pip:
  pip.installed:
    - name: 'buildbot[bundle]'
    - bin_env: {{ buildbot.virtualenv.directory }}
    - require:
      - virtualenv: buildbot_venv

{% for name, master in buildbot.masters.items() %}
{% set root = master.get('root', '/home/' + master.user + '/' + name) %}
buildbot_{{ name }}_user:
  user.present:
    - name: {{ master.user }}

buildbot_{{ name }}_group:
  group.present:
    - name: {{ master.group }}

buildbot_{{ name }}_root:
  file.directory:
    - name: {{ root }}
    - user: {{ master.user }}
    - group: {{ master.group }}
    - makedirs: true

buildbot_{{ name }}_config:
  git.latest:
    - name: {{ master.config_url }}
    - target: {{ root }}
    - user: {{ master.user }}
    - rev: master
    - branch: master
    - force_reset: true
    - force_fetch: true

{% if master.get('has_requirements', False) %}
buildbot_{{ name }}_pip:
  pip.installed:
    - requirements: {{ root }}/requirements.txt
    - bin_env: {{ buildbot.virtualenv.directory }}
    - require:
      - git: buildbot_{{ name }}_config
      - virtualenv: buildbot_venv
{% endif %}

buildbot_{{ name }}_create:
  cmd.run:
    - name: 'sh -c ". {{ buildbot.virtualenv.directory }}/bin/activate && buildbot create-master"'
    - cwd: {{ root }}
    - runas: {{ master.user }}
    - creates: '{{ root }}/buildbot.tac'

buildbot_{{ name }}_upgrade:
  cmd.run:
    - name: 'sh -c ". {{ buildbot.virtualenv.directory }}/bin/activate && buildbot upgrade-master"'
    - cwd: {{ root }}
    - runas: {{ master.user }}
    - creates: '{{ root }}/buildbot.tac'
    - onchanges:
      - git: buildbot_{{ name }}_config
      - pip: buildbot_pip
{% if grains.os_family == 'FreeBSD' %}
{%- set fullname = 'buildbot_' + name -%}
buildbot_{{ name }}_rc:
  file.managed:
    - name: /usr/local/etc/rc.d/{{ fullname }}
    - source: salt://buildbot/files/freebsd-rc.sh
    - template: jinja
    - mode: 755
    - context:
        fullname: {{ fullname | yaml_encode }}
        directory: {{ root | yaml_encode }}
        user: {{ master.user | yaml_encode }}
        virtualenv: {{ buildbot.virtualenv.directory | yaml_encode }}
        executable: buildbot
buildbot_{{ name }}_svc:
  service.running:
    - name: {{ fullname }}
    - enable: true
    - watch:
      - git: buildbot_{{ name }}_config
      - file: buildbot_{{ name }}_rc
{% endif %}
{% endfor %}

{% for name, slave in buildbot.slaves.items() %}
{% set root = slave.get('root', '/home/' + slave.user + '/' + name) %}
buildslave_{{ name }}_user:
  user.present:
    - name: {{ slave.user }}

buildslave_{{ name }}_group:
  group.present:
    - name: {{ slave.group }}

buildslave_{{ name }}_root:
  file.directory:
    - name: {{ root }}
    - user: {{ slave.user }}
    - group: {{ slave.group }}
    - makedirs: true

buildslave_{{ name }}_create:
  cmd.run:
    - name: 'sh -c ". {{ buildbot.virtualenv.directory }}/bin/activate && buildbot-worker create-worker {{ root }} {{ slave.master }} {{ slave.name | default(name) }} {{ slave.password }}"'
    - cwd: {{ root }}
    - runas: {{ slave.user }}
    - creates: '{{ root }}/buildbot.tac'

buildslave_{{ name }}_admin:
  file.managed:
    - name: {{ root }}/info/admin
    - user: {{ slave.user }}
    - group: {{ slave.group }}
    {{ sls_block(slave.admin) | indent(4) }}

buildslave_{{ name }}_host:
  file.managed:
    - name: {{ root }}/info/host
    - user: {{ slave.user }}
    - group: {{ slave.group }}
    {{ sls_block(slave.host) | indent(4) }}
{% if grains.os_family == 'FreeBSD' %}
{%- set fullname = 'buildslave_' + name -%}
buildslave_{{ name }}_rc:
  file.managed:
    - name: /usr/local/etc/rc.d/{{ fullname }}
    - source: salt://buildbot/files/freebsd-rc.sh
    - template: jinja
    - mode: 755
    - context:
        fullname: {{ fullname | yaml_encode }}
        directory: {{ root | yaml_encode }}
        user: {{ slave.user | yaml_encode }}
        virtualenv: {{ buildbot.virtualenv.directory | yaml_encode }}
        executable: buildbot-worker
buildslave_{{ name }}_svc:
  service.running:
    - name: {{ fullname }}
    - enable: true
    - watch:
      - file: buildslave_{{ name }}_admin
      - file: buildslave_{{ name }}_host
{% endif %}
{% endfor %}
