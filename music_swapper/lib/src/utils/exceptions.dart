import 'dart:io';
import 'package:path_provider/path_provider.dart';

///Gets the current line number of the code. Given an offset it will subtract the offset from
///the current line number if it would be a valid line number.
///```dart
///1
///2 final response = getCurrentLine(); //response = 2
///3 final responsePrev = getCurrentLine(offset: 1); //response = 2
///4 final badOffset = getCurrentLine(offset: 10); //response = 4
///```
int getCurrentLine(StackTrace trace, {int offset = 0}){
  if (trace == StackTrace.empty) trace = StackTrace.current;
  final List<String> lines = trace.toString().split('\n');

  String lineStr = lines[0].split(':')[2];
  int lineNum = int.parse(lineStr);

  if (offset > 0 && (lineNum - offset) > 0){
    lineNum -= offset;
  }

   return lineNum;
}//getCurrentLine

///Custom exception to be used as an extension to exception.
class CustomException implements Exception{
  late String _code;
  String? _error;
  late String _userMessage;
  late final StackTrace _stackTrace;

  ///Custom exception Constructor to get custom exceptions for user and developer error messages.
  CustomException({StackTrace stack = StackTrace.empty, String code = 'Failure', String fileName = '', String functionName = '', Object? error = '', int offset = 0, String userMessage = 'Network Connection Issue.'}){
    _code = code;
    _stackTrace = stack;
    _exceptionText(fileName, functionName, error, offset: offset, stack: _stackTrace);
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
  void _exceptionText(String fileName, String functionName, Object? error, {int offset = 0, StackTrace stack = StackTrace.empty}){
    print('\nError in $fileName in function $functionName() line (${getCurrentLine(stack ,offset: offset)}) \n$error\n $stack\n');
  }//exceptionText

}

class FileErrors{
  static Future<void> logError(dynamic error, StackTrace stackTrace) async {
    try {
      // Get the directory for storing files
      Directory directory = await getApplicationDocumentsDirectory();
      File file = File('${directory.path}/error_log.txt');

      // Write error and stack trace to the file
      String errorMessage = '$error\n$stackTrace';
      print(errorMessage);
      await file.writeAsString(errorMessage, mode: FileMode.append);
    } 
    catch (e) {
      // Handle any errors that occur during file writing
      print('Error occurred while saving error to file: $e');
    }
  }
}