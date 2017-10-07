{% from "ossec/map.jinja" import ossec_map with context %}

include:
  - ossec

ossec-agent-packages:
  pkg.installed:
    - pkgs:
      - ossec-hids
      - ossec-hids-agent

{# Use events/reactor system to start up the ossec-authd process on the OSSEC master #}
server-auth:
  cmd.run:
    - name: salt-call event.fire_master 'ossec-auth-start' 'ossec'
    - unless: stat {{ ossec_map.userdir }}/etc/client.keys
    - require:
      - pkg: ossec-agent-packages

{# OSSEC authd agent connects to master and registers its key #}
agent-auth:
  cmd.wait:
    - name: sleep 1 && {{ ossec_map.userdir }}/bin/agent-auth -m {{ ossec_map.server_ip }} -p 1515
    - unless: stat {{ ossec_map.userdir }}/etc/client.keys
    - watch: 
      - cmd: server-auth

{# We are done creating our key so lets shut down the ossec-auth process on the master using reactor #}
server-auth-shutdown:
  cmd.wait:
    - name: salt-call event.fire_master 'ossec-auth-stop' 'ossec'
    - watch:
      - cmd: agent-auth

{# Start the OSSEC services on the agent #}
ossec-service:
  service.running:
    - name: ossec-hids
    - enable: True
    - sig: ossec-syscheckd
    - require:
      - pkg: ossec-agent-packages
      - cmd: agent-auth