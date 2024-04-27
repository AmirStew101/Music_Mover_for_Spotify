
///Model for Spotify API callback object.
///
///Stores the `accessToken`, `refreshToken`, and `expiresAt` (the time the access token expires).
class CallbackModel{
  ///Access token expiration time.
  final double expiresAt;
  ///Used to interact with Spotify API.
  final String accessToken;
  ///Used to refresh the Access token.
  final String refreshToken;

  ///Model for a Spotify API callback object.
  const CallbackModel({
    this.expiresAt = 0,
    this.accessToken = '',
    this.refreshToken = '',
  });

  CallbackModel.defaultCall():
    expiresAt = 0,
    accessToken = '',
    refreshToken = '';

  ///True if the callback doesn't have values.
  bool get isEmpty{
    if (expiresAt == 0 || accessToken == '' || refreshToken == ''){
      return true;
    }
    return false;
  }

  ///True if the callback does have values.
  bool get isNotEmpty{
    if (expiresAt > 0 || accessToken != '' || refreshToken != ''){
      return true;
    }
    return false;
  }
}
