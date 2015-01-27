zero-to-dockerized-meteor
--------------

Dockerizing Meteor talk slide link at 6th Meteor Meetup Seoul

[![ScreenShot](https://raw.githubusercontent.com/jaigouk/zero-to-dockerized-meteor-cluster/master/docs/screenshot.png)](http://www.slideshare.net/jaigouk/dockerizing-meteor-6th-meteor-meetup-seoul)

## STEP0) Prerequisites


* [boot2docker](boot2docker.io)
* [virtualbox](https://www.virtualbox.org/)

```
brew install fleetctl
brew install etcdctl
```


* zsh_alias

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

## STEP1) Dockerize Meeteor App

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

and replica set name in the image is `dbReplicaSet`

According to [mongodb doc](http://docs.mongodb.org/manual/reference/connection-string/), url format to access replica set is

`mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]`

so our url to access replica set we created is

`mongodb://xx.xx.xx.xx:27017,xx.xx.xx.xx:27018,xx.xx.xx.xx:27019/?replicaSet=dbReplicaSet&connectTimeoutMS=300000`
https://stackoverflow.com/questions/26752033/deploying-meteor-js-app-with-docker-and-phusion-passenger

What's cool about etcd is that you can save key/value in it. For example, you can store mongodb url in etcd and use it like this.
```
ExecStart=/bin/bash -c '/usr/bin/docker run --name simple-todos-%i \
                        -p 5000:5000 \
                        --memory="128m" \
                        -e MONGO_URL="$(etcdctl get /mongo/replica/url)" \
                        -e ROOT_URL="http://127.0.0.1" \
                        jaigouk/simple-todos; \
```

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

## STEP2) coreos setup on digitalocean

create coreos instances with private networking and following user data.
Using the `coreos-ssh-import-github` field, we can import public SSH keys from a GitHub user to use as authorized keys to a server.

`curl -w "\n" https://discovery.etcd.io/new`

Since we are using private docker images, we need to setup coreos cluster with .dockercfg file as mentioned in [this coreos document](https://coreos.com/docs/launching-containers/building/registry-authentication/)

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

```
ssh-add ~/.docker/certs/key.pem
```

When you connect to your CoreOS host, pass the -A flag to forward your user agent info so that you can connect to the other cluster members from the one you are logged into

`ssh -A core@xx.xx.xx.xx`
`ssh -A core@xx.xx.xx.xx`
`ssh -A core@xx.xx.xx.xx`

to use fleetctl you need to add fingerprint first.
```
$ ssh -A core@xx.xx.xx.xx
$ FLEETCTL_TUNNEL=xx.xx.xx.xx:22 fleetctl list-machines
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

```
cd zero-to-dockerized-meteor-cluster/fleet/simple_todos
ln -s ../templates/simple-todos@.service simple-todos@1.service
ln -s ../templates/simple-todos@.service simple-todos@2.service
ln -s ../templates/simple-todos@.service simple-todos@3.service
ln -s ../templates/simple-todos-discovery@.service simple-todos-discovery@1.service
ln -s ../templates/simple-todos-discovery@.service simple-todos-discovery@2.service
ln -s ../templates/simple-todos-discovery@.service simple-todos-discovery@3.service
cd ..
fleetctl start simple_todos/*
```


## STEP3) MongoDB Replica Set

You can save actual data in 
1) a coreos dir 
2) another docker container.

If you want to know more about this subject, please visit my [data-only-container repo](https://github.com/jaigouk/data-only-container). For setting up replica set please visit,

1) with a coreos dir : https://github.com/jaigouk/coreos-mongodb
2) with another data container : https://github.com/19hz/coreos-mongodb-cluster

Deploy

```
ssh -A core@xx.xx.xx.xxx 'etcdctl set /mongo/replica/name myReplica'
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

Starting mongodb replica set

```
$ cd to_this_repo/fleet/templates
$ fleetctl start mongo-data@{1..3}.service mongo@{1..3}.service mongo-replica-config.service
```

save mongo url

```
$ SITE_USR_ADMIN_PWD=$(etcdctl get /mongo/replica/siteUserAdmin/pwd 2>/dev/null || true ); \
>     REPLICA_NAME=$(etcdctl get /mongo/replica/name 2>/dev/null || true ); \
>     MONGO_NODES_WITH_COMMA=$(etcdctl ls /mongo/replica/nodes | xargs -I{} basename {} | xargs -I{} printf "%s," {}:27017); \
>     MONGO_NODES=${MONGO_NODES_WITH_COMMA::-1}; \
>     MONGODB="mongodb://siteUserAdmin:"$SITE_USR_ADMIN_PWD"@"$MONGO_NODES"/?replicaSet="$REPLICA_NAME"&connectTimeoutMS=300000";
>  
$ etcdctl set /mongo/replica/url $MONGODB   
```

If you want to destroy and revert everything, then

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



## STEP4) RUN YOUR METEOR APP

Starting  services
```
$ cd to_this_repo/fleet/templates
$ fleetctl start simple-todos@{1..3}.service
$ fleetctl start telescope@{1..3}.service
```


you can run commands like these.
```
fleetctl submit telescope@{1..3}.service && fleetctl start telescope@{1..3}.service
fleetctl list-units
fleetctl status telescope@{1..3}.service
fleetctl journal -f telescope@{1..3}.service
fleetctl stop telescope@{1..3}.service
fleetctl destroy telescope@{1..3}.service
```

Fleet-ui example

```
setup_fleet_ui(){
  do_droplets=(xx.xx.xx.xx xx.xx.xx.xx xx.xx.xx.xx)
  for droplet in ${do_droplets[@]}
  do
    ssh -A core@$droplet 'rm -rf ~/.ssh/id_rsa'
    scp /Users/jaigouk/.docker/certs/key.pem core@$droplet:.ssh/id_rsa
    ssh -A core@$droplet 'chown -R core:core /home/core/.ssh; chmod 700 /home/core/.ssh; chmod 600 /home/core/.ssh/authorized_keys'
  done
  fleetctl destroy fleet-ui@{1..3}.service
  fleetctl destroy fleet-ui@.service
  fleetctl start /Users/your_name/path_to_fleet_templates/fleet-ui@{1..3}.service
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