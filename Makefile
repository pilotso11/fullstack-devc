docker: docker-base docker-pg docker-cloud

docker-base:
	    docker buildx build --platform linux/amd64,linux/arm64 -t pilotso11/fullstack-devc:dev --push .

docker-pg:
	    docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.pg --build-arg BASE_IMAGE=pilotso11/fullstack-devc:dev -t pilotso11/fullstack-devc:dev-pg --push .

docker-cloud:
	    docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.cloud --build-arg BASE_IMAGE=pilotso11/fullstack-devc:dev -t pilotso11/fullstack-devc:dev-cloud --push .
