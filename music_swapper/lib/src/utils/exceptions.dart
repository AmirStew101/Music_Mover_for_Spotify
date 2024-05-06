
///Custom exception to be used as an extension to exception.
class CustomException implements Exception{
  late String _reason;
  Object? _error;
  String _userMessage = 'Network Connection Issue.';
  late final StackTrace _stack;
  bool _fatal = false;
  late final String _fileName;
  late final String _functionName;

  ///Custom exception Constructor to get custom exceptions for user and developer error messages.
  CustomException({bool fatal = true, StackTrace? stack, String? reason, String fileName = '', String functionName = '', Object? error, String? userMessage}){
    _reason = reason ?? 'Failed';
    _stack = stack ?? StackTrace.current;
    _fileName = fileName;
    _functionName = functionName;
    _error = _exceptionText(fileName, functionName, error, _reason);
    _userMessage = userMessage ?? _userMessage;
    _fatal = fatal;
  }

  //Getters and Setters

  ///Get the error message for developer to debug.
  Object? get error => _error;

  /// Get the stack of the error
  StackTrace get stack => _stack;

  ///Get the UI error message for the user.
  String get userMessag => _userMessage;

  bool get fatal => _fatal;

  String? get reason => _reason;

  String get fileName => _fileName;

  String get functionName => _functionName;
  
  //Private

  ///The apps standard throw exception text.
  Object? _exceptionText(String fileName, String functionName, Object? error, String? reason){
    if(reason != null){
      return '\nFirebase Auth Error in $fileName function $functionName()\n Code: $reason\n $error\n';
    }
    return '\nError in $fileName function $functionName()\n $error\n';
  }//exceptionText

}