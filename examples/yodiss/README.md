Prepare environment:
docker-compose -f docker-compose-iroha-iroha.yml up

Run sample:
./iroha-iroha-payment.sh

Clean-up:
docker-compose -f docker-compose-iroha-iroha.yml rm -f


How it looks:
![ILP settlement structure](../../quilt.png)
