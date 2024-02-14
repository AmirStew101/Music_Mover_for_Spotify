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

@app.route('/get-auth-url-no-dialog', methods=['GET'])
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
        'show_dialog': False #Forces the user to login again for Testing
    }

    auth_url = f"{AUTH_URL}?{urllib.parse.urlencode(params)}"

    return jsonify({'status': 'Success', 'data': auth_url})

@app.route('/get-auth-url-dialog', methods=['GET'])
def re_login():
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

    if response.status_code != 200:
        return jsonify({'status': 'Failed', 'message': f'Failed to get playlists: {response.status_code} {response.json()}'})
    
    playlists = response.json()
    playlist_items = playlists['items']

    user_playlists = {}

    i = 0
    for item in playlist_items:
        id = item['id']
        owner = item['owner']['id']
        snapshotId = item['snapshot_id']
        images = item['images']
        link = item['tracks']['href']
        title = item['name']

        if (title == ''):
            title = f'Unnamed {i}'
            i += 1

        user_playlists[id] = {
            'title': title, 
            'link': link, 
            'imageUrl': images, 
            'snapshotId': snapshotId,
            'owner': owner,
        }
        print(f'Title: {title} \n Owner: {owner}')

    #Manually add Liked_Songs playlist
    user_playlists['Liked_Songs'] = {
    'title': 'Liked_Songs', 
    'link': '', 
    'imageUrl': [], 
    'snapshotId': 'Liked_Songs',
    'owner': 'Liked_Songs',
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

        if playlist_id != 'Liked_Songs':
            #Gets the first item of user playlist for Playlist size
            getUrl = API_BASE_URL + 'playlists/' + playlist_id + '/tracks?limit=1'
        else:
            getUrl = API_BASE_URL + 'me/tracks?limit=1'

        response = requests.get(getUrl, headers= header)

        if response.status_code == 200:
            tracks = response.json()
            totalItems = tracks['total']

            return jsonify({'status': 'Success', 'totalTracks': totalItems})
        
        return jsonify({'status': 'Failed', 'message': f'Failed to get track total: {response.status_code} {response.json()}'})
    
    return jsonify({'status': 'Failed', 'message': 'Missing Playlist ID'})

@app.route('/get-all-tracks/<playlist_id>/<expires_at>/<access_token>/<total_tracks>/<offset>')
def get_all_tracks(playlist_id, expires_at, access_token, total_tracks, offset):
    expires_at = float(expires_at)
    total_tracks = int(total_tracks)
    offset = str(offset)

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
    
        response = handleGetTracks(playlist_id, offset, header)

        if response.status_code == 200:
            tracks = response.json()
            tracks_items = tracks['items']
            
            """
            Puts all of a Users tracks in a dictionary 
            with its associated images, preview_url, and artist
            """
            for item in tracks_items:

                #Checks if it is a Spotify track
                if item is not None:
                    track_id = item['track']['id']

                    if track_id is not None:
                        track_title = item['track']['name']
                        track_images = item['track']['album']['images']

                        preview_url = item['track']['preview_url'] or ''
                        
                        track_artist = item['track']['artists'][0]['name']
                        if track_artist and track_images and track_title:
                            duplicate = duplicateCheck(track_id, playlist_tracks)

                            if not duplicate:
                                playlist_tracks[track_id] = {
                                    'title': track_title,
                                    'imageUrl': track_images, 
                                    'artist': track_artist,
                                    'preview_url': preview_url,
                                    'duplicates': 0,
                                }

            return jsonify({'status': 'Success', 'data': playlist_tracks})
        
        else:
            return jsonify({'status': 'Failed', 'message': f'Failed to get all tracks: {response.status_code} {response.json()}'})
           
    return jsonify({'status': 'Failed', 'message': 'Missing Playlist ID'})

def handleGetTracks(playlist_id, offsetStr, header):
    if playlist_id != 'Liked_Songs':
        getUrl = API_BASE_URL + 'playlists/' + playlist_id + f'/tracks?limit=50&offset={offsetStr}'
    else:
        getUrl = API_BASE_URL + f'me/tracks?limit=50&offset={offsetStr}'

    response = requests.get(getUrl, headers=header)
    return response

#Checks if a track is in a playlist multiple times
def duplicateCheck(track_id, playlist_tracks):
    if playlist_tracks.get(track_id):
        playlist_tracks[track_id]['duplicates'] += 1
        return True
    
    return False


@app.route('/add-to-playlists/<expires_at>/<access_token>', methods=['POST'])
def add_tracks(expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return LOGGIN_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return REFRESH_MSG
    
    if 'trackIds' in request.json and 'playlistIds' in request.json:
        tracks = request.json['trackIds']
        playlist_ids = request.json['playlistIds']
        print(f'Received Tracks: {tracks}')
        print(f'Received Playlists: {playlist_ids}')
    
    if playlist_ids and tracks:
        print('Starting Add')
        header = {
                'Authorization': f"Bearer {access_token}",
                'Content-Type': 'application/json'
            }
        
        addUris = []
        likedUris = []
        items = 0

        for track in tracks:
            #Increments the item tracker
            items += 1

            addUri = 'spotify:track:' + track
            addUris.append(addUri)
            likedUris.append(track)

            if (items % 50) == 0 or track == tracks[-1]:
                bodyUri = {"uris": addUris}

                for id in playlist_ids:
                    status = handleAddTracks(header, id, bodyUri, likedUris)
                    print(f'Status: {status}')

                    if status['status'] == 'Failed':
                        return jsonify(status)
                    
                #Resets the tracks when they reach the max 100 tracks
                addUris.clear
                likedUris.clear

    return jsonify('Success')

def handleAddTracks(header, id, bodyUri, likedUris):

    if id != 'Liked_Songs':
        postUrl = f"{API_BASE_URL}playlists/{id}/tracks"

        #Add track to other playlists
        response = requests.post(postUrl, headers=header, json=bodyUri)

    else:
        bodyUri = {'ids': likedUris}
        postUrl = f"{API_BASE_URL}me/tracks"

        #Add track to Liked Songs playlist
        response = requests.put(postUrl, headers=header, json=bodyUri)

    if response.status_code != 201 and response.status_code != 200:
        print(f'Failed to add Track {response.reason}')
        return {'status': 'Failed', 'message': f'Failed to add track: {response.status_code}'}
    else:
        return {'status': 'Success'}


@app.route('/remove-tracks/<origin_id>/<snapshot_id>/<expires_at>/<access_token>', methods=['POST'])
def remove_tracks(origin_id, snapshot_id, expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return LOGGIN_MSG
    
    if not expires_at:
        return EXPIRES_MSG
    
    if expires_at and datetime.now().timestamp() > expires_at:
        print(f'Expires at: {expires_at} \nDatetime: {datetime.now().timestamp()}')
        return REFRESH_MSG
    
    if 'trackIds' in request.json:
        tracks = request.json['trackIds']
    
    if tracks:
        header = {
                'Authorization': f"Bearer {access_token}",
                'Content-Type': 'application/json'
        }
        
        trackUris = []
        likedUris = []
        items = 0

        for track in tracks:
            #Increments the item tracker
            items += 1

            trackUri = {'uri': 'spotify:track:' + track}
            trackUris.append(trackUri)

            likedUris.append(track)

            if (items % 50) == 0 or track == tracks[-1]:
                handleRemoveTracks(origin_id, likedUris, trackUris, snapshot_id, header)
                trackUris.clear()
                likedUris.clear()

    return jsonify('Success')

def handleRemoveTracks(origin_id, likedUris, trackUris, snapshot_id, header):
    #Handles the Liked Songs track removal
    if origin_id == 'Liked_Songs':
        deleteUrl = f"{API_BASE_URL}me/tracks"
        deleteBodyUri = {"ids": likedUris}

    #Handles Playlist track removal 
    else:
        #Delete tracks from playlist
        deleteUrl = f"{API_BASE_URL}playlists/{origin_id}/tracks"
        deleteBodyUri = {"tracks": trackUris, "snapshotId": snapshot_id}

    response = requests.delete(deleteUrl, headers=header, json=deleteBodyUri)

    if response.status_code != 200:
        return jsonify({'status': 'Failed', 'message': f'Failed to remove track from Liked_Songs: {response.status_code} {response.json()}'})


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

    if response.status_code != 200:
        return jsonify({'status': 'Failed', 'message': f'Failed to get user info: {response.status_code} {response.json()}'})

    user_info = response.json()
    print(f'User Object: {user_info}')
    user_name = user_info['display_name']

    if user_name == None:
        user_name = ''

    spot_helper_info = {
        'displayName':  user_name,
        'id': user_info['id'],
        'uri': user_info['uri']
    }
    print(f'User {spot_helper_info}')

    return jsonify({'status': 'Success', 'data': spot_helper_info})

if __name__ == "__main__":
    app.run(debug=True)