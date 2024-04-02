import 'package:flutter/material.dart';

///Gets the current line number of the code. Given an offset it will subtract the offset from
///the current line number if it would be a valid line number.
///```dart
///1
///2 final response = getCurrentLine(); //response = 2
///3 final responsePrev = getCurrentLine(offset: 1); //response = 2
///4 final badOffset = getCurrentLine(offset: 10); //response = 4
///```
int getCurrentLine({int offset = 0}){
  StackTrace trace = StackTrace.current;
  final lines = trace.toString().split('\n');

  String lineStr = lines[1].split(':')[2];
  int lineNum = int.parse(lineStr);

  if (offset > 0 && (lineNum - offset) > 0){
    lineNum -= offset;
  }

   return lineNum;
}//getCurrentLine

///Removes the modified underscore and duplicate number from a track
///```dart
///final response = getTrackId("9s8fs8sd98_1"); //response = "9s8fs8sd98"
///```
String getTrackId(String trackId){
  int underScoreIndex = trackId.indexOf('_');
  String result = trackId;

  if (underScoreIndex != -1){
    result = trackId.substring(0, underScoreIndex);
  }

  return result;
}//getTrackId

///Modifies the users input to remove any potentially problomatic charachters.
String modifyBadQuery(String query){
  List badInput = ['\\', ';', '\'', '"', '@', '|'];
  String newQuery = '';
  for (var char in query.characters){
    if (!badInput.contains(char)){
      newQuery = newQuery + char;
    }
  }
  return newQuery;
}//modifyBadQuery

///Standard grey divider
Divider customDivider(){
  return const Divider(
    color: Colors.grey,
  );
}

///The apps standard throw exception text.
String exceptionText(String fileName, String functionName, Object? error, {int offset = 0}){
  return '$fileName in function $functionName (${getCurrentLine(offset: offset)}) Caught Error: $error';
}