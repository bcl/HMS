' ********************************************************************
' **  Parse an HTML directory listing
' **  Copyright (c) 2010-2013 Brian C. Lane All Rights Reserved.
' ********************************************************************
Function getDirectoryListing(url As String) As Object
    result = getHTMLWithTimeout(url, 60)

    if result.error or result.str = invalid then
'        title = "Directory Listing Error"
'        text  = "There was an error fetching the directory listing."
'        print text
'        ShowErrorDialog(text, title)
        return invalid
    end if

    ' NOTE: I can't find a way to escape a " character with Instr so we have to ASSume it's there.
    dir = CreateObject("roArray", 10, true)
    next_href = 0
    next_quote = -1
    while true
        next_href = result.str.Instr(next_href, "href=")
        if next_href = -1 then
            return dir
        end if
        next_href = next_href + 6
        next_quote = result.str.Instr(next_href, ">")
        if next_quote = -1 then
            return dir
        end if
        next_quote = next_quote - 1
        dir.Push(result.str.Mid(next_href, next_quote-next_href))
        next_href = next_quote + 2
    end while
End Function
