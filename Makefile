#!/usr/bin/make -f

DOCKER_IMAGE:=naftulikay/crowbar:latest

build:
	docker build -t $(DOCKER_IMAGE) .

shell:
	docker run -it --rm $(DOCKER_IMAGE)
