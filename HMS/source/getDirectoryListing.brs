' ********************************************************************
' **  Parse an HTML directory listing
' **  Copyright (c) 2010-2013 Brian C. Lane All Rights Reserved.
' ********************************************************************
Function getDirectoryListing(url As String) As Object
    result = getHTMLWithTimeout(url, 60)

    if result.error then
        title = "Directory Listing Error"
        text  = "There was an error fetching the directory listing."
        print text
        ShowErrorDialog(text, title)

        return invalid
    end if

    ' Split it into lines, assume one entry per-line
    r1 = CreateObject("roRegex", "\n", "")
    ' Extract the href entry from the line
    r2 = CreateObject("roRegex", "href=.(.*?).>", "")
    dir = CreateObject("roArray", 10, true)
    for each l in r1.Split(result.str)
        if r2.isMatch(l) then
            m = r2.Match(l)
'            print m[1]
            dir.Push(m[1])
        end if
    end for
    return dir
End Function

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
    return result.str
End Function

' ***********************************
' * Set a value for a key
' ***********************************
Function setKeyValue(url As String, key As String, value As String)
    result = postHTMLWithTimeout(url+"/keystore/"+key, "value="+value, 60)
    if result.error then
        print "Error ";result.response;" setting key ";key;"=";value;": ";result.reason
    end if
End Function
