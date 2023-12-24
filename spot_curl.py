import subprocess
import json

client_id = "5e6623ad65b7489b879a2a332c133570"
client_secret = "4cd9de386b2c4d5882e7cdd283e6a1e3"

# Replace 'your-client-id' and 'your-client-secret' with your actual values
curl_command = (
    'curl -X POST "https://accounts.spotify.com/api/token" '
    '-H "Content-Type: application/x-www-form-urlencoded" '
    f'-d "grant_type=client_credentials&client_id={client_id}&client_secret={client_secret}"'
)

# Run the cURL command
result = subprocess.run(curl_command, shell=True, capture_output=True, text=True)

result_data = json.loads(result.stdout)

access_token = result_data.get("access_token")

# Access the result
print(result.stdout)

radiohead= "4Z8W4fKeB5YxbusRsdQVPb"

curl_command = ( 
    f'curl "https://api.spotify.com/v1/artists/{radiohead}" '
    f'-H "Authorization: Bearer {access_token}"'
)

result = subprocess.run(curl_command, shell=True, capture_output=True, text=True)

result_data = json.loads(result.stdout)

artist_name = result_data.get("name")
artist_uri = result_data.get("uri")
artist_id = artist_uri.split(":")[-1]


print("Artist name: ", artist_name)
print("Artist uri: ", artist_id)