'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
'********************************************************************

'******************************************************
'** Show the contents of url
'******************************************************
Sub displayDirectory( url ) As Void

    ' Get the directory listing
    files = getDirectoryListing(url)
    if files = invalid then
        print "Failed to get directory listing for"; url
        return
    end if

    'print files

    ' Figure out what kind of directory this is
    ' videos(0) - default, photos(1), songs(2), episodes(3)
    if files.DoesExist("photos") then
        dirType = 1
        displayList  = displayPhotos(files)
    else if files.DoesExist("songs") then
        dirType = 2
        displayList = displaySongs(files)
    else if files.DoesExist("episodes") then
        dirType = 3
        displayList = displayEpisodes(files)
    else
        dirType = 0
        displayList = displayVideos(files)
    end if

    for each f in displayList
        print f[1]
    end for
End Sub

'******************************************************
'** Return a list of the Videos and directories
'**
'** Videos end in the following extensions
'** .mp4 .m4v .mov .wmv
'******************************************************
Sub displayVideos( files As Object ) As Object
    videoTypes = { mp4 : true, m4v : true, mov : true, wmv : true }
    list = []
    for each f in files
        ' This expects the path to have a system volume at the start
        p = CreateObject("roPath", "pkg:/" + f)
        if p.IsValid() then
            fileType = videoTypes[p.Split().extension.mid(1)]
            if fileType = true then
                list.push([f, p.Split()])
            end if
        end if
    end for

    return list
End Sub

