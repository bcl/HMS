'********************************************************************
'**  Home Media Server Application - keystore functions
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************


' ***********************************
' * Get a value for a key
' ***********************************
Function getKeyValue(url As String, key As String) As String
    result = getHTMLWithTimeout(url+"/keystore/"+key, 60)
    if result.error and result.response <> 404 then
        print "Error ";result.response;" getting key ";key;": ";result.reason
        return ""
    elseif result.error and result.response = 404 then
        return ""
    end if

    ' The keyserver returns 'value=XXXX', strip off the value= if present
    return result.str.Replace("value=","")
End Function

' ***********************************
' * Set a value for a key
' For historical reasons the actual value stored includes the string 'value=' at the start.
' ***********************************
Function setKeyValue(url As String, key As String, value As String)
    result = postHTMLWithTimeout(url+"/keystore/"+key, "value="+value, 60)
    if result.error then
        print "Error ";result.response;" setting key ";key;"=";value;": ";result.reason
    end if
End Function
