#!/bin/bash

if [ -n "$1" ]; then
    DROPLET_NAME=$1
    echo "will create $NUM_OF_DROPLETS of $DROPLET_NAME"
else
    DROPLET_NAME=tcore00
fi

echo "=========================="
echo "check vars"
echo "DO_TOKEN: $DO_TOKEN"
echo "DROPLET_NAME: $DROPLET_NAME"
echo "SIZE: $SIZE"
echo "SSH_KEY_ID: $SSH_KEY_ID"
echo "DISCOVERY_URL: $DISCOVERY_URL"
echo "=========================="

DOCKERCFG=$(<~/.dockercfg)
# example
# https://github.com/deis/deis/blob/master/contrib/coreos/user-data.example
#
  # - path: /home/core/.dockercfg
  #   owner: core:core
  #   permissions: 0644
  #   content: |
  #     '"$DOCKERCFG"'

curl -X POST "https://api.digitalocean.com/v2/droplets" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $DO_TOKEN" \
     -d '{"name":"'"$DROPLET_NAME"'",
         "region":"nyc3",
         "image": "coreos-stable",
         "size":"'"$SIZE"'",
         "private_networking":true,
         "ssh_keys":["'"$SSH_KEY_ID"'"],
         "user_data":
"#cloud-config
---
write_files:
  - path: /etc/ssh/sshd_config
    permissions: 0600
    owner: root:root
    content: |
      UsePrivilegeSeparation sandbox
      Subsystem sftp internal-sftp
      PermitRootLogin no
      AllowUsers core
      PasswordAuthentication no
      ChallengeResponseAuthentication no
  - path: /home/core/.dockercfg
    owner: core:core
    permissions: 0644
    content: $DOCKERCFG
coreos:
  etcd:
    # generate a new token for each unique cluster from https://discovery.etcd.io/new
    discovery: '"$DISCOVERY_URL"'
    # use $public_ipv4 if your datacenter of choice does not support private networking
    addr: $private_ipv4:4001
    peer-addr: $private_ipv4:7001
    # give etcd more time if its under heavy load - prevent leader election thrashing
    peer-election-timeout: 2000
    # heartbeat interval should ideally be 1/4 or 1/5 of peer election timeout
    peer-heartbeat-interval: 500
  fleet:
    # allow etcd to slow down at times
    etcd-request-timeout: 3.0
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
        ExecStart=/usr/bin/systemctl enable docker-tcp.socket"}'