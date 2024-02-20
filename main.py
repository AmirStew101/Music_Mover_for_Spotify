"""
Author: Amir Stewart
Description: This API is meant to interact with Spotify in bulk. It will let you select multiple tracks in a playlist by artist/genre/etc. and delete them from a playlist/s,
add them to another playlist/s, copy them to another playlist/s. User can also clear a playlist w/out deleting it, undo the deletions of a playlist within a certain period of time, 
or just undo there recent action.
"""

import requests, urllib.parse

from datetime import datetime, timedelta
from flask import Flask, redirect, request, jsonify, make_response
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
app.secret_key = '234as45-9tvb27418-as987uhld83-1239sad089'

CLIENT_ID = '5e6623ad65b7489b879a2a332c133570'
CLIENT_SECRET = '4cd9de386b2c4d5882e7cdd283e6a1e3'
SITE_REDIRECT_URI = 'https://amirstew.pythonanywhere.com/callback'

HOSTED = 'https://amirstew.pythonanywhere.com'

AUTH_URL = 'https://accounts.spotify.com/authorize'
TOKEN_URL = 'https://accounts.spotify.com/api/token'
API_BASE_URL = 'https://api.spotify.com/v1/'

STATUS = 'status'
SUCCESS = 'Success'
FAILED = 'Failed'
MESSAGE = 'message'

REFRESH_MSG = {STATUS: FAILED, MESSAGE: 'Need refresh token'}
LOGGIN_MSG = {STATUS: FAILED, MESSAGE: 'Not Logged In'}
EXPIRES_MSG = {STATUS: FAILED, MESSAGE: 'No Expiration time received'}

def failed_response(message):
    failed_body = jsonify(message)
    failed = make_response(failed_body)
    failed.status_code = 400
    return failed

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

    return jsonify({STATUS: SUCCESS, 'data': auth_url})

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

    return jsonify({STATUS: SUCCESS, 'data': auth_url})


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

    if response.status_code != 200:
        return failed_response(f'Token Url & Body failed: {response.content}')

    token_info = response.json()

    access_token = token_info['access_token'] #used to make Spotiufy API requests
    refresh_token = token_info['refresh_token'] #Refresh access token when it expires after one day
    expires_at = datetime.now().timestamp() + token_info['expires_in'] #Num of seconds token will last

    info = {'accessToken': access_token, 'refreshToken': refresh_token, 'expiresAt': expires_at}

    return jsonify({STATUS: SUCCESS, 'data': info})

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

        if response.status_code != 200:
            return failed_response(f'Token Url & Body failed: {response.status_code}, {response.content}')
        
        new_token_info = response.json()

        access_token = new_token_info['access_token']
        expires_at = datetime.now().timestamp() + new_token_info['expires_in']

        info = {'accessToken': access_token, 'expiresAt': expires_at, 'refreshToken': refresh_token}

        return jsonify({STATUS: SUCCESS, 'data': info})
    
    return failed_response({MESSAGE: 'Token doesn\'t need to be refreshed'})


@app.route('/get-playlists/<expires_at>/<access_token>')
def get_playlists(expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return failed_response(LOGGIN_MSG)
    
    if not expires_at:
        return failed_response(EXPIRES_MSG)
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return failed_response(REFRESH_MSG)
    
    header = {
        'Authorization': f"Bearer {access_token}"
    }

    #TODO: Make loop to get more than 50 playlists
    getUrl = API_BASE_URL + 'me/playlists?limit=50'
    response = requests.get(getUrl, headers=header)

    if response.status_code != 200:
        return failed_response({MESSAGE: f'Failed to get playlists: {response.status_code} {response.json()}'})
    
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
    return jsonify({STATUS: SUCCESS, 'data': user_playlists})


@app.route('/get-tracks-total/<playlist_id>/<expires_at>/<access_token>')
def get_tracks_total(playlist_id, expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return failed_response(LOGGIN_MSG)
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return failed_response(REFRESH_MSG)
    
    elif not expires_at:
        return failed_response(EXPIRES_MSG)
    
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

        if response.status_code != 200:
            return failed_response({MESSAGE: f'Failed to get track total: {response.status_code} {response.content}'})

        tracks = response.json()
        totalItems = tracks['total']

        return jsonify({STATUS: SUCCESS, 'totalTracks': totalItems})
    
    return failed_response({MESSAGE: 'Missing Playlist ID'})


@app.route('/get-all-tracks/<playlist_id>/<expires_at>/<access_token>/<offset>/')
def get_all_tracks(playlist_id, expires_at, access_token, offset):
    expires_at = float(expires_at)
    offset = str(offset)
    print(f'Offset {offset}')

    if not access_token:
        return failed_response(LOGGIN_MSG)
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return failed_response(REFRESH_MSG)
    
    elif not expires_at:
        return failed_response(EXPIRES_MSG)
    
    #Gets all the tracks for the given playlist id
    if playlist_id:
        header = {
            'Authorization': f"Bearer {access_token}"
        }

        playlist_tracks = {}
    
        response = handleGetTracks(playlist_id, offset, header)

        if response.status_code != 200:
            return failed_response({MESSAGE: f'Failed to get all tracks: {response.status_code} {response.content}'})

        tracks = response.json()
        tracks_items = tracks['items']
        
        """
        Puts all of a Users tracks in a dictionary 
        with its associated images, preview_url, and artist
        """
        for item in tracks_items:

            #Checks if the item is a complete item
            if 'track' in item and item['track'] is not None:
                track_id = item['track']['id']

                if track_id is not None:
                    track_title = item['track']['name']
                    track_images = item['track']['album']['images']
                    preview_url = item['track']['preview_url'] or ''
                    
                    track_artist = item['track']['artists'][0]['name']

                    if track_artist and track_images and track_title:
                        duplicate = duplicateCheck(track_id, playlist_tracks)
                        
                        
                        playlist_tracks[track_id] = {
                            'title': track_title,
                            'imageUrl': track_images, 
                            'artist': track_artist,
                            'preview_url': preview_url,
                            'duplicates': duplicate,
                            'liked': playlist_id == 'Liked_Songs',
                        }
                        
        return jsonify({STATUS: SUCCESS, 'data': playlist_tracks})
        
    return failed_response({MESSAGE: 'Missing Playlist ID'})

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
        dupe = playlist_tracks[track_id]['duplicates'] + 1
        return dupe
    
    return 0

#Check if tracks are in liked Songs
@app.route('/check-liked/<expires_at>/<access_token>', methods=['POST'])
def check_liked(expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return failed_response(LOGGIN_MSG)
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return failed_response(REFRESH_MSG)
    
    elif not expires_at:
        return failed_response(EXPIRES_MSG)
    
    if 'trackIds' in request.json:
        tracks = request.json['trackIds']
    
    if tracks is not None:
        header = {
            'Authorization': f"Bearer {access_token}"
        }

        checkUrl = f"{API_BASE_URL}me/tracks/contains?ids="

        for i in range(len(tracks)):
            if i == len(tracks)-1:
                checkUrl = checkUrl + tracks[i]
            else:
                checkUrl = checkUrl + f"{tracks[i]},"

        #Check if tracks are in Liked Songs
        checkResponse = requests.get(checkUrl, headers=header)

        if checkResponse.status_code != 200:
            return failed_response({MESSAGE: f'Failed to get data from server: {checkResponse.status_code} {checkResponse.content}'})
        
        boolArray = checkResponse.json()
        return {STATUS: SUCCESS, 'boolArray': boolArray}
            

    return failed_response({MESSAGE: 'Missing track Ids'}) 


@app.route('/add-to-playlists/<expires_at>/<access_token>', methods=['POST'])
def add_tracks(expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return failed_response(LOGGIN_MSG)
    
    if not expires_at:
        return failed_response(EXPIRES_MSG)
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return failed_response(REFRESH_MSG)
    
    if 'trackIds' in request.json and 'playlistIds' in request.json:
        tracks = request.json['trackIds']
        playlist_ids = request.json['playlistIds']
    
    if playlist_ids and tracks:
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

                    if status[STATUS] == FAILED:
                        return failed_response(status[MESSAGE])
                    
                #Resets the tracks when they reach the max 100 tracks
                addUris.clear
                likedUris.clear

    return jsonify(SUCCESS)

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
        return {STATUS: FAILED, MESSAGE: f'Failed to add tracks: {response.status_code} {response.content}'}
    else:
        return {STATUS: SUCCESS}


@app.route('/remove-tracks/<origin_id>/<snapshot_id>/<expires_at>/<access_token>', methods=['POST'])
def remove_tracks(origin_id, snapshot_id, expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return failed_response(LOGGIN_MSG)
    
    if not expires_at:
        return failed_response(EXPIRES_MSG)
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return failed_response(REFRESH_MSG)
    
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
                handleResponse = handleRemoveTracks(origin_id, likedUris, trackUris, snapshot_id, header)
                if handleResponse[STATUS] != SUCCESS:
                    return failed_response(handleResponse[MESSAGE])
                
                trackUris.clear()
                likedUris.clear()

    return jsonify(SUCCESS)

def handleRemoveTracks(origin_id, likedUris, trackUris, snapshot_id, header):
    #Handles the Liked Songs track removal
    if origin_id == 'Liked_Songs':
        deleteUrl = f"{API_BASE_URL}me/tracks"
        deleteBodyUri = {"ids": likedUris}

    #Handles Playlist track removal 
    else:
        print('Not Liked Songs Playlist')
        #Delete tracks from playlist
        deleteUrl = f"{API_BASE_URL}playlists/{origin_id}/tracks"
        deleteBodyUri = {"tracks": trackUris, "snapshotId": snapshot_id}

    response = requests.delete(deleteUrl, headers=header, json=deleteBodyUri)

    if response.status_code != 200:
        print('Failed in handleRemoveTracks')
        return {STATUS: FAILED, MESSAGE: f'Failed to remove track from Liked_Songs: {response.status_code} {response.content}'}
    
    return {STATUS: SUCCESS}


@app.route('/get-user-info/<expires_at>/<access_token>')
def get_user_info(expires_at, access_token):
    expires_at = float(expires_at)

    if not access_token:
        return failed_response(LOGGIN_MSG)
    
    if not expires_at:
        return failed_response(EXPIRES_MSG)
    
    if expires_at and datetime.now().timestamp() > expires_at:
        return failed_response(REFRESH_MSG)
    
    header = {
            'Authorization': f"Bearer {access_token}"
    }

    getUrl = f"{API_BASE_URL}me"
    response = requests.get(getUrl, headers=header)

    if response.status_code != 200:
        return failed_response({MESSAGE: f'Failed to get user info: {response.status_code} {response.content}'})

    user_info = response.json()
    user_name = user_info['display_name']

    if user_name == None:
        user_name = ''

    spot_helper_info = {
        'displayName':  user_name,
        'id': user_info['id'],
        'uri': user_info['uri']
    }

    return jsonify({STATUS: SUCCESS, 'data': spot_helper_info})


if __name__ == "__main__":
    app.run(debug=True)