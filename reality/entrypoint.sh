#!/bin/sh
if [ -f /xray/config_info.txt ]; then
  echo "config.json exist"
else
  IPV6=$(curl -6 -sSL --connect-timeout 3 --retry 2  ip.sb || echo "null")
  IPV4=$(curl -4 -sSL --connect-timeout 3 --retry 2  ip.sb || echo "null")
  if [ -z "$UUID" ]; then
    echo "UUID is not set, generate random UUID "
    UUID="$(/xray uuid)"
    echo "UUID: $UUID"
  fi

  if [ -z "$EXTERNAL_PORT" ]; then
    echo "EXTERNAL_PORT is not set, use default value 443"
    EXTERNAL_PORT=443
  fi

  if [ -n "$HOSTMODE_PORT" ];then
    EXTERNAL_PORT=$HOSTMODE_PORT
    jq ".inbounds[0].port=$HOSTMODE_PORT" /xray/config.json >/xray/config.json_tmp && mv /xray/config.json_tmp /xray/config.json
  fi

  if [ -z "$DEST" ]; then
    echo "DEST is not set. default value www.apple.com:443"
    DEST="www.apple.com:443"
  fi

  if [ -z "$SERVERNAMES" ]; then
    echo "SERVERNAMES is not set. use default value [\"www.apple.com\",\"images.apple.com\"]"
    SERVERNAMES="www.apple.com images.apple.com"
  fi

  if [ -z "$PRIVATEKEY" ]; then
    echo "PRIVATEKEY is not set. generate new key"
    /xray x25519 >/key
    PRIVATEKEY=$(cat /key | grep "Private" | awk -F ': ' '{print $2}')
    PUBLICKEY=$(cat /key | grep "Public" | awk -F ': ' '{print $2}')
    echo "Private key: $PRIVATEKEY"
    echo "Public key: $PUBLICKEY"
  fi

  if [ -z "$NETWORK" ]; then
    echo "NETWORK is not set,set default value tcp"
    NETWORK="tcp"
  fi

  # change config
  jq ".inbounds[0].settings.clients[0].id=\"$UUID\"" /xray/config.json >/xray/config.json_tmp && mv /xray/config.json_tmp /xray/config.json
  jq ".inbounds[0].streamSettings.realitySettings.dest=\"$DEST\"" /xray/config.json >/xray/config.json_tmp && mv /xray/config.json_tmp /xray/config.json

  SERVERNAMES_JSON_ARRAY="$(echo "[$(echo $SERVERNAMES | awk '{for(i=1;i<=NF;i++) printf "\"%s\",", $i}' | sed 's/,$//')]")"
  jq --argjson serverNames "$SERVERNAMES_JSON_ARRAY" '.inbounds[0].streamSettings.realitySettings.serverNames = $serverNames' /xray/config.json >/xray/config.json_tmp && mv /xray/config.json_tmp /xray/config.json

  jq ".inbounds[0].streamSettings.realitySettings.privateKey=\"$PRIVATEKEY\"" /xray/config.json >/xray/config.json_tmp && mv /xray/config.json_tmp /xray/config.json
  jq ".inbounds[0].streamSettings.network=\"$NETWORK\"" /xray/config.json >/xray/config.json_tmp && mv /xray/config.json_tmp /xray/config.json




  FIRST_SERVERNAME=$(echo $SERVERNAMES | awk '{print $1}')
  # config info with green color
  echo -e "\033[32m" >/xray/config_info.txt
  echo "IPV6: $IPV6" >>/xray/config_info.txt
  echo "IPV4: $IPV4" >>/xray/config_info.txt
  echo "UUID: $UUID" >>/xray/config_info.txt
  echo "DEST: $DEST" >>/xray/config_info.txt
  echo "PORT: $EXTERNAL_PORT" >>/xray/config_info.txt
  echo "SERVERNAMES: $SERVERNAMES (任选其一)" >>/xray/config_info.txt
  echo "PRIVATEKEY: $PRIVATEKEY" >>/xray/config_info.txt
  echo "PUBLICKEY: $PUBLICKEY" >>/xray/config_info.txt
  echo "NETWORK: $NETWORK" >>/xray/config_info.txt
  if [ "$IPV4" != "null" ]; then
    SUB_IPV4="vless://$UUID@$IPV4:$EXTERNAL_PORT?encryption=none&security=reality&type=$NETWORK&sni=$FIRST_SERVERNAME&fp=chrome&pbk=$PUBLICKEY&flow=xtls-rprx-vision#docker_vless_reality_vision"
    echo "IPV4 订阅连接: $SUB_IPV4" >>/xray/config_info.txt
    echo -e "IPV4 订阅二维码:\n$(echo "$SUB_IPV4" | qrencode -o - -t UTF8)" >>/xray/config_info.txt
  fi
  if [ "$IPV6" != "null" ];then
    SUB_IPV6="vless://$UUID@$IPV6:$EXTERNAL_PORT?encryption=none&security=reality&type=$NETWORK&sni=$FIRST_SERVERNAME&fp=chrome&pbk=$PUBLICKEY&flow=xtls-rprx-vision#docker_vless_reality_vision"
    echo "IPV6 订阅连接: $SUB_IPV6" >>/xray/config_info.txt
    echo -e "IPV6 订阅二维码:\n$(echo "$SUB_IPV6" | qrencode -o - -t UTF8)" >>/xray/config_info.txt
  fi


  echo -e "\033[0m" >>/xray/config_info.txt

fi

# show config info
cat /xray/config_info.txt

# run xray
exec /xray -config /xray/config.json
