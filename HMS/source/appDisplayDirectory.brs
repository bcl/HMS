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
        displayList  = displayFiles(files, { jpg : true })
    else if files.DoesExist("songs") then
        dirType = 2
        displayList = displayFiles(files, { mp3 : true })
    else if files.DoesExist("episodes") then
        dirType = 3
        displayList = displayFiles(files, { mp4 : true, m4v : true, mov : true, wmv : true } )
    else if files.DoesExist("movies") then
        dirType = 4
        displayList = displayFiles(files, { mp4 : true, m4v : true, mov : true, wmv : true } )
    else
        dirType = 0
        displayList = displayFiles(files, {}, true)
    end if

    ' Sort the list, case-insensitive
    Sort( displayList, function(k)
                           return LCase(k[0])
                       end function)

'    for each f in displayList
'        print f[0]
'        print f[1]
'    end for
    if dirType = 0 then
        ret = showCategories( displayList )
    end if

End Sub

'******************************************************
'** Return a list of the Videos and directories
'**
'** Videos end in the following extensions
'** .mp4 .m4v .mov .wmv
'******************************************************
Sub displayFiles( files As Object, fileTypes As Object, dirs=false As Boolean ) As Object
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
End Sub

'******************************************************
'** Display a flat-category poster screen of items
'** return the one selected by the user or nil?
'******************************************************
Sub showCategories( files As Object ) As Object
    screen = CreateObject("roPosterScreen")
    screen.SetBreadcrumbText("bc-1", "bc-2")
    screen.SetMessagePort(m.port)
    screen.SetListStyle("flat-category")
    screen.SetListDisplayMode("zoom-to-fill")

    list = CreateObject("roArray", files.Count(), true)
    for each f in files
        print f

        o = CreateObject("roAssociativeArray")
        o.ContentType = "episode"
        o.ShortDescriptionLine1 = f[1]["basename"]

        print o
        list.Push(o)
    end for

    screen.SetContentList(list)
    screen.Show()

    done = false
    while not done
        msg = wait(0, m.port)
        print msg
        if msg = invalid or msg.isScreenClosed() then
            return -1
        else if msg.isListItemSelected() then
            print "msg: ";msg.GetMessage();" idx: ";msg.GetIndex()
        end if
    end while
End Sub

