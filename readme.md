## 

### Docker base image including the following services / programs

- PHP 7.4.13-FPM
- NGINX
- NODE
- YARN

### To build the base image
```bash
# format: docker build -f {php-version}-Dockerfile --tag {image name} --build-arg USER=${USER} .
cd php
docker build -f ./php7.4.13-Dockerfile --tag php:7.4.13-fpm --build-arg USER=${USER} .

```


### To build the development or staging image
```bash
docker build -f ./Dockerfile --target {target} --tag {image_name} --build-arg USER=${USER} .
# --target : This is to instruct to build up until the base tag in Dockerfile. For development use "base" while for staging use the tag "staging" following the Dockerfile tag
# -f : file target
# --build-arg : provide argument for building. Default we pass in USER=${USER} to get the user name from the current cli session
```

### Example use docker-compose
Before using: ensure the settings are correct:
1. change `container_name` under service
2. change `image` name which it will compile
3. ensure the mount volumes are correct
4. network `outside` is used if you have an external docker-compose running and wish to able to hook up. Eg: internal docker here trying to connect to a database defined outside of this docker-compose in laradock

```bash
docker-compose up -d
# -d : for detach
```


### Example deploy to AWS Lightsail
```bash
# Prerequisite:
# Go to AWS Lightsail, create a container service (note: not instance, but the new container deployment in Lightsail)
#
# 1. Build the image following the above step
# 2. push to AWS lightsail via CLI. (ensure AWS CLI version is >2.20)

# Example command below:

aws lightsail push-container-image [--profile {your_profile_name}] --region ap-southeast-1 --service-name {service name defined in AWS lightsail} --label {label without colon AWS will auto append versioning for you} --image {local image tag}

# Differe example
aws lightsail push-container-image --profile byronwongdev --region ap-southeast-1 --service-name php-service --label staging --image image:0.1
```