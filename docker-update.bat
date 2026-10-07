echo updating docker images
docker-compose pull

echo stoping container
docker-compose down

echo recreating container, starting up and removing orphans...
docker-compose up -d --force-recreate --remove-orphans --force-recreate

docker compose up -d
echo done
pause