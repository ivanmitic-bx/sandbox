HOST=$1
VHOST=$2
UNAME=$3
UPASS=$4
APP_UNAME=$5

if [[ -z $HOST || -z $VHOST || -z $UNAME || -z $UPASS || -z $APP_UNAME ]]; then
  echo "Usage: $0 host vhost username password aplication_username"
  exit 1;
fi

echo "working with: host: $HOST, vhost: $VHOST, creds: $UNAME:$UPASS, application username: $APP_UNAME"

# Create vhost
curl -X DELETE -u $UNAME:$UPASS -H "content-type:application/json" "http://$HOST/api/vhosts/$VHOST";

# Create vhost
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" "http://$HOST/api/vhosts/$VHOST";

# Give permission to admin
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" -d '{"configure":".*","write":".*","read":".*"}' "http://$HOST/api/permissions/$VHOST/$UNAME";

# Give permission to application user
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" -d '{"configure":".*","write":".*","read":".*"}' "http://$HOST/api/permissions/$VHOST/$APP_UNAME";

# Default exchange & queue:
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" -d '{"type":"fanout","auto_delete":false,"durable":true,"internal":false,"arguments":{}}' "http://$HOST/api/exchanges/$VHOST/label.default";
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" -d '{"auto_delete":false,"durable":true}' "http://$HOST/api/queues/$VHOST/label.default";
curl -X POST -u $UNAME:$UPASS -H "content-type:application/json" -d '{"routing_key":"","arguments":{}}' "http://$HOST/api/bindings/$VHOST/e/label.default/q/label.default";

# Hub specific exchange (to be bound dynamically, to hub dedicated queues - as needed)
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" -d '{"type":"topic","auto_delete":false,"durable":true,"internal":false,"arguments":{"alternate-exchange": "label.default"}}' "http://$HOST/api/exchanges/$VHOST/label.hub-specific";

# Merchant specific exchange (to be bound dynamically, to merchant dedicated queues - as needed)
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" -d '{"type":"topic","auto_delete":false,"durable":true,"internal":false,"arguments":{"alternate-exchange": "label.hub-specific"}}' "http://$HOST/api/exchanges/$VHOST/label.merchant-specific";

# Label specific exchange (to be bound to queue dynamically, as needed)
curl -X PUT -u $UNAME:$UPASS -H "content-type:application/json" -d '{"type":"direct","auto_delete":false,"durable":true,"internal":false,"arguments":{"alternate-exchange": "label.merchant-specific"}}' "http://$HOST/api/exchanges/$VHOST/label.specific";
