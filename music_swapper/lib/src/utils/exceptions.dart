
///Custom exception to be used as an extension to exception.
class CustomException implements Exception{
  late String _code;
  String? _error;
  late String _userMessage;
  late final StackTrace _stackTrace;

  ///Custom exception Constructor to get custom exceptions for user and developer error messages.
  CustomException({StackTrace stack = StackTrace.empty, String code = 'Failure', String fileName = '', String functionName = '', Object? error = '', String userMessage = 'Network Connection Issue.'}){
    _code = code;
    _stackTrace = stack;
    _exceptionText(fileName, functionName, error, stack: _stackTrace);
    _userMessage = userMessage;
  }

  //Getters and Setters

  ///Get the error message for developer to debug.
  get error{
    return _error;
  }

  ///Get the UI error message for the user.
  get userMessage{
    return _userMessage;
  }

  String get code => _code;
  
  //Private

  ///The apps standard throw exception text.
  void _exceptionText(String fileName, String functionName, Object? error, {StackTrace stack = StackTrace.empty}){
    print('\nError in $fileName in function $functionName() \n$error\n $stack\n');
  }//exceptionText

}