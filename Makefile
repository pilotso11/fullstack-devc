docker:
	    docker buildx build --platform linux/amd64,linux/arm64 -t pilotso11/fullstack-devc:dev --push .

docker-pg:
	    docker buildx build --platform linux/amd64,linux/arm64 --build-arg INCLUDE_POSTGRES=true -t pilotso11/fullstack-devc:dev-pg --push .

docker-cloud:
	    docker buildx build --platform linux/amd64,linux/arm64 --build-arg INCLUDE_CLOUD=true -t pilotso11/fullstack-devc:dev-cloud --push .
