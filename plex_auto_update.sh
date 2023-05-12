#!/bin/bash


# Path to last version file
plex_version_file="./plex_version.txt"

# Check if last version file exists, create if not
if [ ! -f "$plex_version_file" ]; then
  touch "$plex_version_file"
fi

plex_version=$(cat "$plex_version_file")


# Path to x-plex-token file
xplex_token_file="./x-plex_token.txt"

# Check if x-plex token file exists, create if not
if [ ! -f "$xplex_token_file" ]; then
  touch "$xplex_token_file"
fi

xplex_token=$(cat "$xplex_token_file")

# Get JSON response from API
epoch=$(date +%s)
download_url="https://plex.tv/api/downloads/5.json?channel=plexpass&_="$epoch"&X-Plex-Token="$xplex_token""
response=$(curl -s $download_url)

# Make the API call and extract the url, latest version and checksum
url=$(echo $response | jq -r '.computer.FreeBSD.releases[0].url')
checksum=$(echo $response | jq -r '.computer.FreeBSD.releases[0].checksum')
version=$(echo $response | jq -r '.computer.FreeBSD.version')

echo "API Link: $download_url"
echo "Lastest Version: $version"
echo "Latest URL: $url"
echo " Latest Checksum: $checksum"

if [ -z "$url" ]; then
  echo "Error: Please provide the URL of the Plex update file."
  exit 1
fi

if [ -z "$checksum" ]; then
  echo "Error: Please provide the Plex update SHA-1 checksum."
  exit 1
fi

# Extract the file name from the URL
filename=$(echo "$url" | awk -F '/' '{print $NF}' | awk -F '?' '{print $1}')

# Remove the prefix
dl_version=${filename#PlexMediaServer-}

# Remove the suffix
dl_version=${version%-FreeBSD-amd64.tar.bz2}

echo "Download Version = $dl_version"

if [ $version == $dl_version ]; then
  echo "Already at the latest version."
  exit 1
fi

# Print the basename of the downloaded file
echo "Downloading $filename"

# Download the update file to a temporary directory
if ! fetch -o "/tmp/$filename" "$url"; then
  echo "Error: Failed to download the update file."
  exit 1
fi

# Verify the SHA-1 checksum
if ! sha1 -q "/tmp/$filename" | grep -q "$2"; then
  echo "Error: The SHA-1 checksum does not match the downloaded file."
  rm "/tmp/$filename"
  exit 1
fi

# Stop the Plex Media Server
ps aux
service plexmediaserver_plexpass stop

# Extract the update file directly into the Plex directory
if ! tar -xjf "/tmp/$filename" -C /usr/local/share/plexmediaserver-plexpass/ --strip-components=1; then
  echo "Error: Failed to extract the update file."
  exit 1
fi

# Delete the downloaded update file
rm "/tmp/$filename"

# Start the Plex Media Server
#systemctl start plexmediaserver
service plexmediaserver_plexpass start

ps aux

echo "$version" > "$plex_version_file"
