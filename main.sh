#!/bin/bash

print() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $@"
}

# Cloudflare api base url
base_url="https://api.cloudflare.com/client/v4/zones/$zone_id"
base_header=(-H "Authorization: Bearer $api_token" -H "Content-Type:application/json")

# Check account information is correct
response=$(curl -s -X GET "$base_url" "${base_header[@]}")
if ! echo "$response" | jq -e '.success' | grep -q 'true'; then
  print "Authentication failed, please check if your Cloudflare account information is correct"
  exit 1
fi

print "Start execute the speedtest"
# Execute the speedtest
chmod +x CloudflareST
./CloudflareST "${speedtest_para[@]}" > /dev/null 2>&1

# Check if execute successful
if [[ ! -f result.csv ]]; then
  print "Cloudflare speed test failed"
  exit 1
fi

# Get old dns and delete it
response=$(curl -sm10 -X GET "$base_url/dns_records?name=$host_name&type=A" "${base_header[@]}")
if echo "$response" | jq -r '.success' | grep -q 'true'; then
  records=$(echo "$response" | jq -r '.result')
  if [[ $(echo "$records" | jq 'length') -gt 0 ]]; then
    for record in $(echo "$records" | jq -c '.[]'); do
      record_id=$(echo "$record" | jq -r '.id')
      response=$(curl -sm10 -X DELETE "$base_url/dns_records/$record_id" "${base_header[@]}")
      if ! echo "$response" | jq -r '.success' | grep -q 'true'; then
        print "Delete dns record failed"
      fi
    done
    print "Successfully deleted dns: $host_name"
  else
    print "Not found dns records"
  fi
fi

declare -a ips
num=$(awk -F, 'END {print NR-1}' result.csv)
x=0  # Initialize counter
# 3 ips to dns
while [[ ${x} -lt ${num} && ${#ips[@]} -lt 3 ]]; do
  ipAddr=$(sed -n "$((x + 2)),1p" result.csv | awk -F, '{print $1}')
  ipSpeed=$(sed -n "$((x + 2)),1p" result.csv | awk -F, '{print $6}')

  if [[ $ipSpeed == "0.00" ]]; then
    print "No.$((x + 1))---$ipAddr speedtest is 0, skip this dns update"
  else
    # Append the IP address to the ips array
    ips+=("$ipAddr")
  fi

  x=$((x + 1))  # Increment counter
done

for ip in "${ips[@]}"; do
  if [[ "$ip" =~ ":" ]]; then
    record_type="AAAA"
  else
    record_type="A"
  fi
  data='{
      "type": "'"$record_type"'",
      "name": "'"$host_name"'",
      "content": "'"$ip"'",
      "ttl": 1,
      "proxied": false
  }'
  response=$(curl -s -X POST "$base_url/dns_records" "${base_header[@]}" -d "$data")
  if echo "$response" | jq -r '.success' | grep -q 'true'; then
    print "Successfully added dns: $host_name with ip address: $ip"
  else
    print "Update ip address: ${ip} failed"
  fi
  sleep 1
done

rm result.csv