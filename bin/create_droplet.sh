#!/bin/bash

if [ -n "$1" ]; then
    DROPLET_NAME=$1
else
    DROPLET_NAME=tcore00
fi

curl -X POST "https://api.digitalocean.com/v2/droplets" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $DO_TOKEN" \
     -d'{"name":"'"$DROPLET_NAME"'",
         "region":"nyc3",
         "image": "coreos-stable",
         "size":"'"$SIZE"'",
         "private_networking":true,
         "ssh_keys":["'"$SSH_KEY_ID"'"],
         "user_data":
"#cloud-config
coreos:
  etcd:
    # generate a new token for each unique cluster from https://discovery.etcd.io/new
    discovery: '"$DISCOVERY_URL"'
    # use $public_ipv4 if your datacenter of choice does not support private networking
    addr: $private_ipv4:4001
    peer-addr: $private_ipv4:7001
  fleet:
    public-ip: $private_ipv4        # used for fleetctl ssh command
    metadata: region=nyc3,public_ip=$public_ipv4
  units:
    - name: etcd.service
      command: start
    - name: fleet.service
      command: start
    - name: sshd.socket
      command: restart
      content: |
        [Socket]
        ListenStream=2631
        Accept=yes
    - name: docker-tcp.socket
      command: start
      enable: yes
      content: |
        [Unit]
        Description=Docker Socket for the API
        [Socket]
        ListenStream=2376
        BindIPv6Only=both
        Service=docker.service
        [Install]
        WantedBy=sockets.target
    - name: enable-docker-tcp.service
      command: start
      content: |
        [Unit]
        Description=Enable the Docker Socket for the API
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/systemctl enable docker-tcp.socket
write_files:
  - path: /home/core/.dockercfg
    owner: core:core
    permissions: 0644
    content: |
      {
        "https://index.docker.io/v1/": {
          "auth": "'"$DOCKERIO_TOKEN"'",
          "email": "'"$DOCKERIO_EMAIL"'"
        }
      }
  - path: /etc/ssh/sshd_config
    permissions: 0600
    owner: root:root
    content: |
      # Use most defaults for sshd configuration.
      UsePrivilegeSeparation sandbox
      Subsystem sftp internal-sftp
      PermitRootLogin no
      AllowUsers core
      PasswordAuthentication no
      ChallengeResponseAuthentication no"}'