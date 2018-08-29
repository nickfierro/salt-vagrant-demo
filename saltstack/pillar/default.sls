# Default pillar values
# vi: set ft=yaml:

# example docker registry container
# if you want to your own docker registry, use this
docker-containers:
  lookup:

    # example docker registry container (if you want your own docker registry, use this)
    registry:
      #image: 'docker.io/registry:latest'  ##Fedora
      image: "registry:latest"
      cmd:
      # Pull image on service restart (useful if you override the same tag. example: latest)
      pull_before_start: True
      # Do not force container removal on stop (unless true)
      remove_on_stop: false
      runoptions:
        - "-e REGISTRY_LOG_LEVEL=warn"
        - "-e REGISTRY_STORAGE=s3"
        - "-e REGISTRY_STORAGE_S3_REGION=us-west-1"
        - "-e REGISTRY_STORAGE_S3_BUCKET=my-bucket"
        - "-e REGISTRY_STORAGE_S3_ROOTDIRECTORY=/registry"
        - "--log-driver=syslog"
        - "-p 5000:5000"
        - "--rm"
      stopoptions:
        - '-t 10'

    prometheus-server:
      # example Prometheus container using command arguments
      image: "prom/prometheus:v1.7.1"
      cmd:
      args:
        - '-config.file=/prom-data/prometheus.yml'
        - '-storage.local.path=/prom-data/data/'
      # Pull image on service restart (useful if you override the same tag. example: latest)
      pull_before_start: True
      # Do not force container removal on stop (unless true)
      remove_on_stop: false
      runoptions:
        - '--net="host"'
        - '-v /mnt/prom-data:/prom-data'
      stopoptions:
        - '-t 10'

# Docker service
docker-pkg:
  lookup:
    process_signature: /usr/bin/docker

    # config for sysvinit/upstart (for systemd, use drop-ins in your own states)
    config:
      - DOCKER_OPTS="-s btrfs --dns 8.8.8.8"
      - export http_proxy="http://172.17.42.1:3128"

# Docker compose supported attributes
docker:
  # version of docker-compose to install (defaults to latest)
  #compose_version: 1.9.0
  #configfile: /etc/default/docker

  pkg:
  # Package handling
    #version: 1.13.1
    #allow_updates: True

  # PIP proxy configuration (defaults to False)
  # proxy: proxy.com:3128

  # Global functions for docker_container states
  containers:
    skip_translate: ports
    force_present: False
    force_running: True

  compose:
    registry-datastore:
      dvc: True
      # image: &registry_image 'docker.io/registry:latest' ## Fedora
      image: &registry_image 'registry:latest'
      container_name: &dvc 'registry-datastore'
      command: echo *dvc data volume container
      volumes:
        - &datapath '/registry'
    registry-service:
      image: *registry_image
      container_name: 'registry-service'
      volumes_from:
        - *dvc
      environment:
        SETTINGS_FLAVOR: 'local'
        STORAGE_PATH: *datapath
        SEARCH_BACKEND: 'sqlalchemy'
        REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: '/registry'
      ports:
        - 127.0.0.1:5000:5000
      #restart: 'always'    # compose v1.9
      deploy:               # compose v3
        restart_policy:
          condition: on-failure
          delay: 5s
          max_attempts: 3
          window: 120s

   nginx-latest:
      #image: 'docker.io/nginx:latest'  ##Fedora
      image: 'nginx:latest'
      container_name: 'nginx-latest'
      links:
        - 'registry-service:registry'
      ports:
        - '80:80'
        - '443:443'
      volumes:
        - /srv/docker-registry/nginx/:/etc/nginx/conf.d
        - /srv/docker-registry/auth/:/etc/nginx/conf.d/auth
        - /srv/docker-registry/certs/:/etc/nginx/conf.d/certs
      #restart: 'always'    # compose v1.9
      deploy:               # compose v3
        restart_policy:
          condition: on-failure
          delay: 5s
          max_attempts: 3
          window: 120s


hardening:
  login_defs:
    extra_user_paths:
      - /somewhere/bin
    umask: '027'
    password_max_age: 60
    password_min_age: 7
    login_retries: 5
    login_timeout: 60
    chfn_restrict: ''
    allow_login_without_home: false
  network:
    ip_fowarding: 0
    ipv6_disable: True
    arp_restricted: True
  kernel:
    modules_disabled: True
  allow_change_user: False
