
///Model for Spotify API callback object.
///
///Stores the `accessToken`, `refreshToken`, and `expiresAt` (the time the access token expires).
class CallbackModel{
  ///Access token expiration time.
  double expiresAt;
  ///Used to interact with Spotify API.
  String accessToken;
  ///Used to refresh the Access token.
  String refreshToken;

  ///Model for a Spotify API callback object.
  CallbackModel({
    this.expiresAt = 0,
    this.accessToken = '',
    this.refreshToken = '',
  });

  void updateTokens({required double expires, required String access, required String refresh}){
    expiresAt = expires;
    accessToken = access;
    refreshToken = refresh;
  }

  ///True if the callback doesn't have values.
  bool get isEmpty{
    if (expiresAt == 0 || accessToken == '' || refreshToken == ''){
      return true;
    }
    return false;
  }

  ///True if the callback does have values.
  bool get isNotEmpty{
    if (expiresAt != 0 || accessToken != '' || refreshToken != ''){
      return true;
    }
    return false;
  }

  @override
  String toString(){
    return 'Expires At: ${expiresAt.toString()}, Access Token: $accessToken, Refresh Token: $refreshToken';
  }
}
