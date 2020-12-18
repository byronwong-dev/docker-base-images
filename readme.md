###
Docker base image including the following services / programs

- PHP 7.4-FPM
- NGINX
- NODE
- YARN

To build the image
```bash
# format: docker build -f {php-version}-Dockerfile --tag {image name} --build-arg USER=${USER} .
cd php
docker build -f php7.4-Dockerfile --tag php7.4-nginx --build-arg USER=${USER} .

```