docker:
	    docker buildx build --platform linux/amd64,linux/arm64 -t pilotso11/fullstack-devc:dev --push .
