"""
Author: Amir Stewart
Description: This API is meant to interact with Spotify in bulk. It will let you select multiple tracks in a playlist by artist/genre/etc. and delete them from a playlist/s,
add them to another playlist/s, copy them to another playlist/s. User can also clear a playlist w/out deleting it, undo the deletions of a playlist within a certain period of time, 
or just undo there recent action.
"""

import requests, urllib.parse

from datetime import datetime, timedelta
from flask import Flask, redirect, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
app.secret_key = '234as45-9tvb27418-as987uhld83-1239sad089'

CLIENT_ID = '5e6623ad65b7489b879a2a332c133570'
CLIENT_SECRET = '4cd9de386b2c4d5882e7cdd283e6a1e3'
SITE_REDIRECT_URI = 'https://amirstew.pythonanywhere.com/callback'
APP_REDIRECT_URI = "SpotHelper://callback"

NGROK = 'https://b893-173-66-70-24.ngrok-free.app'
HOSTED = 'https://amirstew.pythonanywhere.com'

AUTH_URL = 'https://accounts.spotify.com/authorize'
TOKEN_URL = 'https://accounts.spotify.com/api/token'
API_BASE_URL = 'https://api.spotify.com/v1/'

REFRESH_MSG = {'status': 'Failed', 'message': 'Need refresh token'}
LOGGIN_MSG = {'status': 'Failed', 'message': 'Not Logged In'}
EXPIRES_MSG = {'status': 'Failed', 'message': 'No Expiration time received'}

#For debugging without app use
# @app.route('/')
# def index():
#     return "Spotify <a href='/get-auth-url/not'>Login</a>"

@app.route('/get-auth-url', methods=['GET'])
def login():
    """
    To see playlists: playlist-read-private
    To see playlist tracks: 

    To add tracks from playlist: POST
    To remove tracks from playlist: DELETE
    To create a playlist: playlist-modify-private playlist-modify-public
    """
    scope = 'playlist-read-private playlist-modify-private playlist-modify-public user-library-read user-library-modify user-read-private'

    params = {
        'client_id': CLIENT_ID,
        'response_type': 'code',
        'scope': scope,
        'redirect_uri': SITE_REDIRECT_URI,
        'show_dialog': True #Forces the user to login again for Testing
    }

    auth_url = f"{AUTH_URL}?{urllib.parse.urlencode(params)}"

    return jsonify({'status': 'Success', 'data': auth_url})


@app.route('/callback')
def callback():
    if 'error' in request.args:
        return jsonify({'error': request.args['error']})
    
    if 'code' in request.args:
        req_body = {
            'code': request.args['code'],
            'grant_type': 'authorization_code',
            'redirect_uri': SITE_REDIRECT_URI,
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET
        }

    response = requests.post(TOKEN_URL, data=req_body)

    token_info = response.json()

    access_token = token_info['access_token'] #used to make Spotiufy API requests
    refresh_token = token_info['refresh_token'] #Refresh access token when it expires after one day
    expires_at = datetime.now().timestamp() + token_info['expires_in'] #Num of seconds token will last

    info = {'accessToken': access_token, 'refreshToken': refresh_token, 'expiresAt': expires_at}

    return jsonify({'status': 'Success', 'data': info})

#Refreshes the token when called
@app.route('/refresh-token/<expires_at>/<refresh_token>')
def refresh_token(expires_at, refresh_token):

    expires_at = float(expires_at)

    if not refresh_token:
        return REFRESH_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at:
        req_body = {
            'grant_type': 'refresh_token',
            'refresh_token': refresh_token,
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET
        }

        response = requests.post(TOKEN_URL, data=req_body)
        new_token_info = response.json()

        access_token = new_token_info['access_token']
        expires_at = datetime.now().timestamp() + new_token_info['expires_in']

        info = {'accessToken': access_token, 'expiresAt': expires_at, 'refreshToken': refresh_token}

        return jsonify({'status': 'Success', 'data': info})
    
    return jsonify({'status': 'Failed', 'message': 'Token doesn\'t need to be refreshed'})


@app.route('/get-playlists/<expires_at>/<access_token>')
def get_playlists(expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return LOGGIN_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return REFRESH_MSG
    
    header = {
        'Authorization': f"Bearer {access_token}"
    }

    #TODO: Make loop to get more than 50 playlists
    getUrl = API_BASE_URL + 'me/playlists?limit=50'
    response = requests.get(getUrl, headers=header)

    playlists = response.json()
    playlist_items = playlists['items']

    user_playlists = {}

    i = 1
    for item in playlist_items:
        if (item['name'] == ''):
            unnamed = f'Unnamed {i}'
            user_playlists[item['id']] = {
                'title': unnamed, 
                'link': item['tracks']['href'], 
                'imageUrl': item['images'], 
                'snapshotId': item['snapshot_id'],
                'owner': item['owner']['display_name'],
            }
            i += 1
        else:
            user_playlists[item['id']] = {
                'title': item['name'], 
                'link': item['tracks']['href'], 
                'imageUrl': item['images'], 
                'snapshotId': item['snapshot_id'],
                'owner': item['owner']['display_name'],
            }

    #Manually add Liked Songs playlist
    user_playlists['Liked Songs'] = {
    'title': 'Liked Songs', 
    'link': '', 
    'imageUrl': [], 
    'snapshotId': 'Liked Songs',
    'owner': 'Liked Songs',
    }

    """
    Return the playlist image, its name, its ID
    Name & Img shown to user
    ID for backend search
    """
    return jsonify({'status': 'Success', 'data': user_playlists})


@app.route('/get-tracks-total/<playlist_id>/<expires_at>/<access_token>')
def get_tracks_total(playlist_id, expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return LOGGIN_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return REFRESH_MSG
    
    elif not expires_at:
        return EXPIRES_MSG
    
    if playlist_id:
        header = {
            'Authorization': f"Bearer {access_token}"
        }

        if playlist_id != 'Liked Songs':
            #Gets the first item of user playlist for Playlist size
            getUrl = API_BASE_URL + 'playlists/' + playlist_id + '/tracks?limit=1'
        else:
            getUrl = API_BASE_URL + 'me/tracks?limit=1'

        response = requests.get(getUrl, headers= header)

        tracks = response.json()
        totalItems = tracks['total']

        return jsonify({'status': 'Success', 'totalTracks': totalItems})
    
    return jsonify({'status': 'Failed', 'message': 'Missing Playlist ID'})


@app.route('/get-all-tracks/<playlist_id>/<expires_at>/<access_token>/<total_tracks>')
def get_all_tracks(playlist_id, expires_at, access_token, total_tracks):
    expires_at = float(expires_at)
    total_tracks = int(total_tracks)

    if not access_token:
        return LOGGIN_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return REFRESH_MSG
    
    elif not expires_at:
        return EXPIRES_MSG
    
    #Gets all the tracks for the given playlist id
    if playlist_id:
        header = {
            'Authorization': f"Bearer {access_token}"
        }

        playlist_tracks = {}
        
        for offset in range(0, total_tracks, 50 ):
            offsetStr = str(offset)

            if playlist_id != 'Liked Songs':
                getUrl = API_BASE_URL + 'playlists/' + playlist_id + f'/tracks?limit=50&offset={offsetStr}'
            else:
                getUrl = API_BASE_URL + f'me/tracks?limit=50&offset={offsetStr}'

            response = requests.get(getUrl, headers=header)

            if response.status_code == 200:
                tracks = response.json()
                tracks_items = tracks['items']
                
                """
                Puts all of a Users tracks in a dictionary 
                with its associated images, preview_url, and artist
                """
                for item in tracks_items:
                    track_id = item['track']['id']

                    if track_id is not None:
                        track_title = item['track']['name']
                        track_images = item['track']['album']['images']

                        preview_url = item['track']['preview_url'] or ''
                        
                        track_artist = item['track']['artists'][0]['name']
                        if track_artist and track_images and track_title:
                            playlist_tracks[track_id] = {
                                'title': track_title,
                                'imageUrl': track_images, 
                                'artist': track_artist,
                                'preview_url': preview_url,
                            }

        return jsonify({'status': 'Success', 'data': playlist_tracks})
           
    return jsonify({'status': 'Failed', 'message': 'Missing Playlist ID'})


@app.route('/move-to-playlists/<origin_id>/<snapshot_id>/<expires_at>/<access_token>', methods=['POST', 'DELETE'])
def move_tracks(origin_id, snapshot_id, expires_at, access_token):
    expires_at = float(expires_at)
    tracks = request.json['trackIds']
    playlist_ids = request.json['playlistIds']

    if not access_token:
        return LOGGIN_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return REFRESH_MSG
    
    if origin_id and playlist_ids and tracks:

        add_url = f'{HOSTED}/add-to-playlists/{expires_at}/{access_token}'
        add_body = {'trackIds': tracks, 'playlistIds': playlist_ids}

        try:
            add_response = requests.post(add_url, json=add_body)
        except Exception as e:
            return jsonify(f'Error tring to Add Tracks: {e}')

        if add_response.status_code == 200:
            delete_url = f'{HOSTED}/remove-tracks/{origin_id}/{snapshot_id}/{expires_at}/{access_token}'
            delete_body = {'trackIds': tracks}

            try:
                delete_response = requests.post(delete_url, json=delete_body) 
            except Exception as e:
                return jsonify(f'Error tring to Delete Tracks: {e}')

        return jsonify('Success')
    
    return jsonify('Failed')


@app.route('/add-to-playlists/<expires_at>/<access_token>', methods=['POST'])
def add_tracks(expires_at, access_token):
    expires_at = float(expires_at)
    tracks = request.json['trackIds']
    playlist_ids = request.json['playlistIds']

    if not access_token:
        return LOGGIN_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return REFRESH_MSG
    
    if playlist_ids and tracks:
        header = {
                'Authorization': f"Bearer {access_token}",
                'Content-Type': 'application/json'
            }
        
        trackUris = []
        likedUris = []
        items = 0

        for track in tracks:
            addUri = 'spotify:track:' + track
            trackUris.append(addUri)
            likedUris.append(track)

            if (items % 100) or track == tracks[-1]:
                bodyUri = {"uris": trackUris}

                for play_id in playlist_ids:
                    if play_id != 'Liked Songs':
                        postUrl = f"{API_BASE_URL}playlists/{play_id}/tracks"
                    else:
                        bodyUri = {'ids': likedUris}
                        postUrl = f"{API_BASE_URL}me/tracks"
        
                    #Add track to chosen playlist
                    requests.post(postUrl, headers=header, json=bodyUri)

                trackUris.clear

    return jsonify('Success')


@app.route('/remove-tracks/<origin_id>/<snapshot_id>/<expires_at>/<access_token>', methods=['POST'])
def remove_tracks(origin_id, snapshot_id, expires_at, access_token):
    expires_at = float(expires_at)
    tracks = request.json['trackIds']

    if not access_token:
        return LOGGIN_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        print(f'Expires at: {expires_at} \nDatetime: {datetime.now().timestamp()}')
        return REFRESH_MSG
    
    if tracks:
        header = {
                'Authorization': f"Bearer {access_token}",
                'Content-Type': 'application/json'
        }
        
        trackUris = []
        items = 0

        #Handles tracks for Liked Songs
        if origin_id == 'Liked_Songs':
            for track in tracks:
                trackUris.append(track)

                if (items % 100) or track == tracks[-1]:
                    deleteUrl = f"{API_BASE_URL}me/tracks"
                    deleteBodyUri = {"ids": trackUris}

                    response = requests.delete(deleteUrl, headers=header, json=deleteBodyUri)
                    print(f'Delete Response: {response}')

            trackUris.clear()

        #Handles tracks for a Playlist
        else:
            for track in tracks:
                trackUri = 'spotify:track:' + track
                trackUris.append(trackUri)

                if (items % 100) or track == tracks[-1]:
                    #Delet tracks from old playlist
                    deleteUrl = f"{API_BASE_URL}playlists/{origin_id}/tracks"
                    deleteList = []

                    for item in trackUris:
                        deleteList.append({"uri": item})

                    deleteBodyUri = {"tracks": deleteList, "snapshotId": snapshot_id}

                    response = requests.delete(deleteUrl, headers=header, json=deleteBodyUri)
                    print(f'Delete Response: {response.json()}')

                trackUris.clear()

    return jsonify('Success')

@app.route('/get-user-info/<expires_at>/<access_token>')
def get_user_info(expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return LOGGIN_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return REFRESH_MSG
    
    header = {
            'Authorization': f"Bearer {access_token}"
    }

    getUrl = f"{API_BASE_URL}me"
    response = requests.get(getUrl, headers=header)

    user_info = response.json()
    user_name = user_info['display_name']
    if user_name == None:
        user_name = 'userName'

    spot_helper_info = {
        'user_name':  user_name,
        'id': user_info['id'],
        'uri': user_info['uri']
    }

    return jsonify({'status': 'Success', 'data': spot_helper_info})

if __name__ == "__main__":
    app.run(debug=True)