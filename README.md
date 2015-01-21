zero-to-dockerized-meteor
--------------

## prerequisites

[DropletManager : digitalcoean droplet manager app](https://github.com/deivuh/DODropletManager-OSX/releases)
[boot2docker](boot2docker.io)
[virtualbox](https://www.virtualbox.org/)

```
brew install fleetctl
brew install etcdctl
```


### zsh_alias

```

docker-ip(){
  boot2docker ip 2> /dev/null
}
# docker-enter script is in /Users/jaigouk/bin

# for deleting old containers and images

checkitout (){
  check_boot2docker=$(boot2docker status | awk '{print $1}')
  if [ $check_boot2docker == 'running' ];then
    docker ps -a | grep 'Exit' | awk '{print $1}' | xargs docker rm &> /dev/null
    docker images | grep '<none>' | awk '{print $3}' | xargs docker rmi &> /dev/null
  else
    echo "boot2docker is down. boot it up!"
    boot2docker up
  fi
}


use-boot2docker(){
  boot2docker start
   export DOCKER_HOST=tcp:/xx.xx.xx.xx:2376
    export DOCKER_CERT_PATH=/Users/jaigouk/.boot2docker/certs/boot2docker-vm
    export DOCKER_TLS_VERIFY=1
    export CURRENT_VM_IP=$(boot2docker ip 2> /dev/null)
    RPROMPT="%{$fg[magenta]%}[boot2docker:$CURRENT_VM_IP]%{$reset_color%}"
}
```

boot2docker is using sock to use docker command and certs for ssh and tls.
```
.boot2docker ❯ tree
.
├── boot2docker-vm.sock
├── boot2docker.iso
└── certs
    └── boot2docker-vm
        ├── ca.pem
        ├── cert.pem
        └── key.pem
```

I aliased machine to docker-machine because of os x's machine command.

bin/docker-enter
```
#!/bin/bash
set -e
 
# Check for nsenter. If not found, install it
boot2docker ssh '[ -f /var/lib/boot2docker/nsenter ] || docker run --rm -v /var/lib/boot2docker/:/target jpetazzo/nsenter'
 
# Use bash if no command is specified
args=$@
if [[ $# = 1 ]]; then
  args+=(/bin/bash)
fi
 
boot2docker ssh -t sudo /var/lib/boot2docker/docker-enter "${args[@]}"

```

For fleet
```
setup_fleet(){
  do_droplets=(xx.xx.xx.xx xx.xx.xx.xx xx.xx.xx.xx)
  for droplet in ${do_droplets[@]}
  do
    ssh -A core@$droplet 'rm -rf ~/.ssh/id_rsa'
    scp /Users/name/.docker/certs/key.pem core@$droplet:.ssh/id_rsa
    ssh -A core@$droplet 'chown -R core:core /home/core/.ssh; chmod 700 /home/core/.ssh; chmod 600 /home/core/.ssh/authorized_keys'
  done
  fleetctl destroy fleet-ui@{1..3}.service
  fleetctl destroy fleet-ui@.service
  fleetctl submit  /Users/name/path_to_fleet_file_dir/fleet-ui@.service
  fleetctl start /Users/name/path_to_fleet_file_dir/fleet-ui@{1..3}.service
}

fleetctl-switch(){
  ssh-add ~/.docker/certs/key.pem
  export DOCKER_HOST=tcp://$1:2376
  export DOCKER_AUTH=identity
  export FLEETCTL_TUNNEL=$1:22
  alias etcdctl="ssh -A core@$1 'etcdctl'"
  alias clear_mongo="\
    fleetctl destroy mongo@{1..3}.service; \
    fleetctl destroy mongo-replica-config.service; \
    fleetctl destroy mongo-data@{1..3}.service; \
    etcdctl rm /mongo/replica/siteRootAdmin --recursive; \
    etcdctl rm /mongo/replica/siteUserAdmin --recursive; \
    etcdctl rm /mongo/replica --recursive; \
    etcdctl set /mongo/replica/name myreplica; \
    ssh -A core@$1 'etcdctl ls /mongo --recursive';
  "
  alias fleetctl-ssh="fleetctl ssh $(fleetctl list-machines | cut -c1-8 | sed -n 2p)"
  RPROMPT="%{$fg[magenta]%}[fleetctl:$1]%{$reset_color%}"
}

```

## Dockerize Meeteor App

add `.dockerignore` and `dockerfile`. and create replica set by following [mongodb-replica-set](https://github.com/inlight-media/docker-mongodb-replica-set)

```
$docker build -t="inlight/mongodb-replica-set" github.com/inlight-media/docker-mongodb-replica-set

$ docker run -i -t -d -p 27017:27017 -p 27018:27018 -p 27019:27019 --name mongodb inlight/mongodb-replica-set
$ docker exec -it mongodb bash
$ mongo
> rs.initiate()
>  rs.add('6e8d183167b4:27018') # use token in 'me'
>  rs.add('6e8d183167b4:27019')
>  rs.status()
```


to get the ip address of the machine, type
`boot2docker ip 2> /dev/null` 

and replicaca set name in the image is `dbReplicaSet`

According to [mongodb doc](http://docs.mongodb.org/manual/reference/connection-string/), url format to access replica set is

`mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]`

so our url to access replica set we created is

`mongodb:/xx.xx.xx.xx:27017,xx.xx.xx.xx:27018,xx.xx.xx.xx:27019/?replicaSet=dbReplicaSet&connectTimeoutMS=300000`
https://stackoverflow.com/questions/26752033/deploying-meteor-js-app-with-docker-and-phusion-passenger


Dockerfile
```
FROM phusion/passenger-nodejs:latest

RUN apt-get update
RUN npm cache clean -f && npm install -g n && n 0.10.35
RUN curl https://install.meteor.com/ | sh
RUN npm install --silent -g forever

ADD . ./meteorsrc
WORKDIR /meteorsrc

RUN meteor build --directory .
RUN cd bundle/programs/server && npm install

WORKDIR /meteorsrc/bundle/
ENV PORT 8080
EXPOSE 8080

RUN touch .foreverignore
CMD forever  --minUptime 1000 --spinSleepTime 1000 -w ./main.js
```

```
cd to/your/project
docker build -t lab80/sm_meteor .

docker run --name sm_meteor -p 8080:8080 -e ROOT_URL=" http://127.0.0.1" -e MONGO_URL="mongodb:/xx.xx.xx.xx:27017,xx.xx.xx.xx:27018,xx.xx.xx.xx:27019/?replicaSet=dbReplicaSet&connectTimeoutMS=300000" lab80/sm_meteor

```


setting up autommated builds on docker hub. 

for submodules, add web hook as described in [docker-hub doc](http://docs.docker.com/docker-hub/builds/#github-submodules)

for bitbucket, I copied deploy key from docker hub and added to submodule's bitbucket repo deplyment key in settings.

or you can just `docker push lab80/sm_meteor`

## coreos setup on digitalocean

create coreos instances with private networking and following user data.
Using the `coreos-ssh-import-github` field, we can import public SSH keys from a GitHub user to use as authorized keys to a server.

`curl -w "\n" https://discovery.etcd.io/new`

```
#cloud-config

coreos:
  update:
    reboot-strategy: etcd-lock
  etcd:
    discovery: https://discovery.etcd.io/xxx
    addr: $private_ipv4:4001
    peer-addr: $private_ipv4:7001
  fleet:
    public-ip: $private_ipv4
  units:
    - name: etcd.service
      command: start
    - name: fleet.service
      command: start
 
```

```
ssh-add ~/.docker/certs/key.pem
```

When you connect to your CoreOS host, pass the -A flag to forward your user agent info so that you can connect to the other cluster members from the one you are logged into

`ssh -A core@xx.xx.xx.xx`
`ssh -A core@xx.xx.xx.xx`
`ssh -A core@xx.xx.xx.xx`

to use fleetui 
```
scp ~/.docker/certs/key.pem core@104.xx.xx.xx.xx:
scp ~/.docker/certs/key.pem core@104.xx.xx.xx.xx:
scp ~/.docker/certs/key.pem core@104.xx.xx.xx.xx:

ssh -A core@104.236.83.147
mv key.pem ~/.ssh/id_rsa
chown -R core:core ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa

```
and check `fleetctl list-machines` inside of one instance. If you do not see the result of the command as followed, then you should recreate the cluster with a new etcd token.

```
core@core-1 ~ $ fleetctl list-machines
MACHINE   IP    METADATA
fd82e763... 104.xx.xx.xx.xx  -
ba34bcfd... 104.xx.xx.xx.xx  -
de856979... 104.xx.xx.xx.xx  -
```


`fleetctl --endpoint http://xx.xx.xx.xx:4001 list-machines`
or
`fleetctl --tunnel xx.xx.xx.xx:22 list-units`


```
switch(){
  export FLEETCTL_TUNNEL=$1:22
  export ETCDCTL_PEERS=$1:4001
  RPROMPT="%{$fg[magenta]%}[fleetctl:$1]%{$reset_color%}"
}
```

now you can just run 
`fleetctl list-machines` or `etcdctl ls / --recursive`

## Services
unitfile
```
[Unit]
Description=A Redis Server
[Service]
TimeoutStartSec=0
ExecStartPre=/usr/bin/docker pull redis
ExecStart=/usr/bin/docker run --rm -p 6379 --name redis
ExecStop=/usr/bin/docker stop redis
```

commands
```
fleetctl submit redis.service && fleetctl start redis.service
fleetctl list-units
fleetctl status redis.service
fleetctl journal redis.service
fleetctl stop redis.service
fleetctl destroy redis.service
```



To run fleet-ui

```
fleetctl submit fleet-ui.1.service && fleetctl start fleet-ui.1.service
fleetctl submit fleet-ui.2.service && fleetctl start fleet-ui.2.service
fleetctl submit fleet-ui.3.service && fleetctl start fleet-ui.3.service
```

to destory them,
```
fleetctl destroy fleet-ui.1.service
fleetctl destroy fleet-ui.2.service
fleetctl destroy fleet-ui.3.service
```



## MongoDB replica

Deploy
```
ssh -A core@xx.xx.xx.xxx 'etcdctl set /mongo/replica/name lab80replica'
fleetctl submit mongo-replica-config.service
fleetctl submit mongo@.service
fleetctl start mongo@{1..3}.service mongo-replica-config.service
```
Connect

You can test connecting to your replica from one of your nodes as follows:
```
export SITE_ROOT_PWD=$(ssh -A core@xx.xx.xx.xx etcdctl get /mongo/replica/siteRootAdmin/pwd)
export REPLICA=$(ssh -A core@xx.xx.xx.xx etcdctl get /mongo/replica/name)
export FIRST_NODE=$(fleetctl list-machines --no-legend | awk '{print $2}' | head -n 1)
alias remote_mongo="docker run -it --rm mongo:2.8 mongo $REPLICA/$FIRST_NODE/admin -u siteRootAdmin -p $SITE_ROOT_PWD"
```

`remote_mongo` 

$ Welcome to the MongoDB shell.

Destroy and revert everything
```
# remove all units
$ fleetctl destroy mongo@{1..3}.service
$ fleetctl destroy mongo-replica-config.service
# or
$ fleetctl list-units --no-legend | awk '{print $1}' | xargs -I{} fleetctl destroy {}

# clean directories
$ fleetctl list-machines --fields="machine" --full --no-legend | xargs -I{} fleetctl ssh {} "sudo rm -rf /var/mongo/*"

(from inside one of the nodes)
$ etcdctl rm /mongo/replica/key
$ etcdctl rm --recursive /mongo/replica/siteRootAdmin
$ etcdctl rm --recursive /mongo/replica/siteUserAdmin
$ etcdctl rm --recursive /mongo/replica/nodes

```

# DigitalOcean

Since we are using private docker images, we need to setup coreos cluster with .dockercfg file as mentioned in [this coreos document](https://coreos.com/docs/launching-containers/building/registry-authentication/)

use quay.io to make robots. docker hub is not ideal to use for automation yet.

```
#cloud-config

coreos:
  etcd:
    addr: $private_ipv4:4001
    discovery: "https://discovery.etcd.io/xxxxxx"
    peer-addr: $private_ipv4:7001
  units:
    - name: etcd.service
      command: start
    - name: fleet.service
      command: start
write_files:
    - path: /home/core/.dockercfg
      owner: core:core
      permissions: 0644
      content: |
        {
          "https://index.docker.io/v1/": {
            "auth": "xXxXxXxXxXx=",
            "email": "username@example.com"
          },
          "https://index.example.com": {
            "auth": "XxXxXxXxXxX=",
            "email": "username@example.com"
          }
        }
```



# References

* [Runnning Heapster on CoreOS](https://github.com/GoogleCloudPlatform/heapster/tree/master/clusters/coreos) Heapster enables cluster monitoring in a CoreOS cluster using cAdvisor.

* [mongodb replica on coreos by auth0](https://github.com/auth0/coreos-mongodb)

* [confd](https://github.com/kelseyhightower/confd)is specifically crafted to watch distributed key-value stores for changes. It is run from within a Docker container and is used to trigger configuration modifications and service reloads.

* [10 Things You Should Know About Running MongoDB At Scale](http://highscalability.com/blog/2014/3/5/10-things-you-should-know-about-running-mongodb-at-scale.html)

* [Deploying Docker Containers on CoreOS Using Fleet](http://seanmcgary.com/posts/deploying-docker-containers-on-coreos-using-fleet)

* [Zero Downtime Frontend Deploys with Vulcand on CoreOS](https://coreos.com/blog/zero-downtime-frontend-deploys-vulcand/)

* [Getting Started with CoreOS (digitalocean tutorial)](https://www.digitalocean.com/community/tutorial_series/getting-started-with-coreos-2)

* [How to correctly configure CoreOS iptables on Vultr](https://masato.github.io/2014/11/07/how-to-correctly-coreos-iptables-on-vultr/)