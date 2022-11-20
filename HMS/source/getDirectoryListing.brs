'********************************************************************
'**  Home Media Server Application - Directory listing functions
'**  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
'********************************************************************

' ********************************************************************
' Parse an HTML directory listing
'
' Pass the server url, it returns an array of all the a href paths.
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

'******************************************************
'** Return a list of the Videos and directories
'**
'** Videos end in the following extensions
'** .mp4 .m4v .mov .wmv
'******************************************************
Function displayFiles(files As Object, fileTypes As Object, dirs=false As Boolean) As Object
    list = []
    for each f in files
        ' This expects the path to have a system volume at the start
        p = CreateObject("roPath", "pkg:/" + f)
        if p.IsValid() and f.Left(1) <> "." then
            fileType = fileTypes[p.Split().extension.mid(1)]
            if (dirs and f.Right(1) = "/") or fileType = true then
                list.push([f, p.Split()])
            end if
        end if
    end for

    return list
End Function
