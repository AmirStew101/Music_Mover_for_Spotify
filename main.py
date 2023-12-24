"""
Author: Amir Stewart
Description: This API is meant to interact with Spotify in bulk. It will let you select multiple tracks in a playlist by artist/genre/etc. and delete them from a playlist/s,
add them to another playlist/s, copy them to another playlist/s. User can also clear a playlist w/out deleting it, undo the deletions of a playlist within a certain period of time, 
or just undo there recent action.
"""

import requests, urllib.parse

from datetime import datetime, timedelta
from flask import Flask, redirect, request, jsonify, session
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
app.secret_key = '234as45-9tvb27418-as987uhld83-1239sad089'

CLIENT_ID = '5e6623ad65b7489b879a2a332c133570'
CLIENT_SECRET = '4cd9de386b2c4d5882e7cdd283e6a1e3'
REDIRECT_URI = 'http://localhost:5000/callback'

AUTH_URL = 'https://accounts.spotify.com/authorize'
TOKEN_URL = 'https://accounts.spotify.com/api/token'
API_BASE_URL = 'https://api.spotify.com/v1/'

"""@app.route('/')
def index():
    return "Spotify <a href='/login'>Login</a>"""

@app.route('/login', methods=['GET'])
def login():
    print("LOGIN")
    """
    To see playlists: playlist-read-private
    To see playlist tracks: 

    To add tracks from playlist: POST
    To remove tracks from playlist: DELETE
    To create a playlist: playlist-modify-private playlist-modify-public
    """
    scope = 'playlist-read-private playlist-modify-private playlist-modify-public'

    params = {
        'client_id': CLIENT_ID,
        'response_type': 'code',
        'scope': scope,
        'redirect_uri': REDIRECT_URI,
        'show_dialog': True #Forces the user to login again for Testing
    }

    auth_url = f"{AUTH_URL}?{urllib.parse.urlencode(params)}"
    print(auth_url)

    return auth_url

@app.route('/callback')
def callback():
    if 'error' in request.args:
        return jsonify({'error': request.args['error']})
    
    if 'code' in request.args:
        req_body = {
            'code': request.args['code'],
            'grant_type': 'authorization_code',
            'redirect_uri': REDIRECT_URI,
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET
        }

    response = requests.post(TOKEN_URL, data=req_body)

    token_info = response.json()

    access_token = token_info['access_token'] #used to make Spotiufy API requests
    refresh_token = token_info['refresh_token'] #Refresh access token when it expires after one day
    expires_at = datetime.now().timestamp() + token_info['expires_in'] #Num of seconds token will last

    info = {'access_token': access_token, 'refresh_token': refresh_token, 'expires_at': expires_at}

    return info

@app.route('/playlists')
def get_playlists():
    if 'access_token' not in session:
        return redirect('/login')
    
    if datetime.now().timestamp() > session['expires_at']:
        return redirect('/refresh-token')
    
    header = {
        'Authorization': f"Bearer {session['access_token']}"
    }

    response = requests.get(API_BASE_URL + 'me/playlists', headers=header)

    playlists = response.json()
    playlist_items = playlists['items']
    """print("Playlist ID: ", playlist_items[0]['id'])
    print("Playlist items length: ", len(playlist_items))
    
    print("Playlist ID:", item['id'])
    print("Playlist name:", item['name'])
    print("Track link for get:", item['tracks']['href'])
    print("Images:", item['images'], '\n') #Three sizes for the same image"""

    """
    Return the playlist image, its name, its ID
    Name & Img shown to user
    ID for backend search
    """
    return jsonify(playlists)

@app.route('/tracks/')
def get_tracks():
    if 'access_token' not in session:
        return redirect('/login')
    
    if datetime.now().timestamp() > session['expires_at']:
        return redirect('/refresh-token')
    
    track_link = request.json['track_link']

    header = {
        'Authorization': f"Bearer {session['access_token']}"
    }

    response = requests.get(track_link, headers=header)
    pass

@app.route('/refresh-token')
def refresh_token():
    if 'refresh_token' not in session:
        return redirect('/login')
    
    if datetime.now().timestamp() > session['expires_at']:
        req_body = {
            'grant_type': 'refresh_token',
            'refresh_token': session['refresh_token'],
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET
        }

        response = requests.post(TOKEN_URL, data=req_body)
        new_token_info = response.json()

        session['access_token'] = new_token_info['access_token']
        session['expires_at'] = datetime.now().timestamp() + new_token_info['expires_in']

        return redirect('/playlists')

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)