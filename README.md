zero-to-dockerized-meteor
--------------

Dockerizing Meteor talk slide link at 6th Meteor Meetup Seoul

[![ScreenShot](https://raw.githubusercontent.com/jaigouk/zero-to-dockerized-meteor-cluster/master/docs/screenshot.png)](http://www.slideshare.net/jaigouk/dockerizing-meteor-6th-meteor-meetup-seoul)


# Deploy steps

### STEP0) create cert files

follow this [docker doc](https://docs.docker.com/articles/https/) and put them in `~/.docker/certs/key.pem`

### STEP1) Setup digitalocean
```
cd bin
./deploy.sh -n 3 -o staging -t xxx -s 4gb -k <id>

```

usage. if you don't know or don't have digitalocean token, visit [this page](https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2#how-to-generate-a-personal-access-token). And it's ok if you don't know SSH_KEY_ID. script will show the json result if you provide digitalocean token(read + write). just copy id and paste then hit enter.

```
Usage: $0 [-k ssh key id] [-t digitalocean v2 token] [-o droplet name prefix] [-n number of droplets] [-e etcd token] [-s droplet size]

Options:
    -k SSH_KEY_ID         SSH KEY ID on digitalocean. you need digitalocean token to get it.
    -t DO_TOKEN           digitalocean api v2 token that has read/write permission
    -o DROPLET_NAME       name prefix for droplets. core => core-1, core-2, core-3
    -n INPUT_NUM          default 3
    -e ETCD_TOKEN         without this option, we will get one by default
    -s DROPLET_SIZE       512mb|1gb|2gb|4gb|8gb|16gb

```

### STEP2) launch fleet services

```
source ./bin/shell_env
fleetctl-switch <do-ip-1>
setup_fleet_ui <do-ip-1> <do-ip-2> <do-ip-3>
cd ./fleet/coreos-mongodb-cluster
start_mongo_replica <do-ip-1>
fleetctl start ./fleet/nginx_lb/nginx_lb.service
fleetctl start ./fleet/simple_todos/*
fleetctl start ./fleet/dockerized-drone/*.service
```

### STEP3) DNS Setup (namecheap)

Once the droplet is up and running you should have an IP address to work with. If you're using namecheap, go to the "All Host Records" page of namecheap's "My Account > Manage Domains > Modify Domain" section.

You'll need an A record for the naked domain (the "@" one) pointing to your IP with the lowest TTL possible (namecheap caps the minimum at 60), and a wildcard for subdomains with the same info. I'd recommend redirecting www to the naked domain.

It should look something like this when you're done entering your data.

| HOST NAME | IP ADDRESS/URL | RECORD TYPE | MX PREF | TTL |
| --- | --- | --- | --- | --- |
| @ | your.ip.address.k.thx | A (Address) | n/a | 60 |
| www | http://your.domain | URL Redirect (301) | n/a | 60 |
| * | your.ip.address.k.thx | A (Address) | n/a | 60 |

# References

[Automatic Docker Deployment With Codeship](https://xivilization.net/~marek/blog/2014/10/11/automatic-docker-deployment-with-codeship/)

[Codeship Blog](http://blog.codeship.com/?s=docker)

[Giant swarm blog: Getting Started with Microservices using Ruby on Rails and Docker](http://blog.giantswarm.io/getting-started-with-microservices-using-ruby-on-rails-and-docker)

[martinfowler: microservice-testing](http://martinfowler.com/articles/microservice-testing/)

[Rainforest: Docker in Action - Development to Delivery, Part 2](https://blog.rainforestqa.com/2014-12-08-docker-in-action-from-deployment-to-delivery-part-2-continuous-integration/)