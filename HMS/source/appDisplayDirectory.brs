'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
'********************************************************************

'******************************************************
'** Show the contents of url
'******************************************************
Function displayDirectory( url As String ) As Object
    print "url: ";url

    port=CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)
    screen.SetListStyle("flat-category")
    screen.SetListDisplayMode("zoom-to-fill")

    ' Get last element of URL to use as a breadcrumb
    toks = url.tokenize("/")
    bc1 = ""
    bc2 = toks[toks.Count()-1]
    screen.SetBreadcrumbText(bc1, bc2)
    screen.Show()

    ' Get the directory listing
    dir = getDirectoryListing(url)
    print "got listing"
    if dir = invalid then
        print "Failed to get directory listing for";url
        return invalid
    end if

    ' Figure out what kind of directory this is
    ' dirs(0) - default, photos(1), songs(2), episodes(3), movies(4)
    if dir.DoesExist("photos") then
        dirType = 1
        displayList  = displayFiles(dir, { jpg : true })
    else if dir.DoesExist("songs") then
        dirType = 2
        displayList = displayFiles(dir, { mp3 : true })
    else if dir.DoesExist("episodes") then
        dirType = 3
        displayList = displayFiles(dir, { mp4 : true, m4v : true, mov : true, wmv : true } )
    else if dir.DoesExist("movies") then
        dirType = 4
        displayList = displayFiles(dir, { mp4 : true, m4v : true, mov : true, wmv : true } )
    else
        dirType = 0
        displayList = displayFiles(dir, {}, true)
    end if

    ' Sort the list, case-insensitive
    Sort( displayList, function(k)
                           return LCase(k[0])
                       end function)

'    print "dirType: ";dirType
'    for each f in displayList
'        print f[0]
'        print f[1]
'    end for

    if displayList.Count() = 0 then
        return invalid
    end if

    if dirType = 0 then
        ret = showCategories( screen, displayList, dir, url )
        if ret <> invalid then
            return ret[1]["basename"]
        else
            return invalid
        end if
    else
        return invalid
    end if

End Function

'******************************************************
'** Return a list of the Videos and directories
'**
'** Videos end in the following extensions
'** .mp4 .m4v .mov .wmv
'******************************************************
Function displayFiles( files As Object, fileTypes As Object, dirs=false As Boolean ) As Object
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

'******************************************************
'** Display a flat-category poster screen of items
'** return the one selected by the user or nil?
'******************************************************
Function showCategories( screen As Object, files As Object, dir as Object, url as String ) As Object
    sdImageTypes = []
    sdImageTypes.Push("-SD.jpg")
    sdImageTypes.Push("-SD.png")
    hdImageTypes = []
    hdImageTypes.Push("-HD.jpg")
    hdImageTypes.Push("-HD.png")

    list = CreateObject("roArray", files.Count(), true)
    for each f in files
        o = CreateObject("roAssociativeArray")
        o.ContentType = "episode"
        o.ShortDescriptionLine1 = f[1]["basename"]

        o.SDPosterUrl = "pkg:/dir-SD.png"
        o.HDPosterUrl = "pkg:/dir-HD.png"
        ' poster images in the dir?
        for each i in sdImageTypes
            if dir.DoesExist(f[1]["basename"]+i) then
                o.SDPosterUrl = url + f[1]["basename"] + i
                exit for
            end if
        end for

        for each i in hdImageTypes
            if dir.DoesExist(f[1]["basename"]+i) then
                o.HDPosterUrl = url + f[1]["basename"] + i
                exit for
            end if
        end for

        list.Push(o)
    end for

    screen.SetContentList(list)
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        print msg
        if msg = invalid or msg.isScreenClosed() then
            ' UP appears to close the screen, so we get here
            print "screen closed"
            return invalid
        else if msg.isListItemSelected() then
            print "msg: ";msg.GetMessage();" idx: ";msg.GetIndex()
            return files[msg.GetIndex()]
        end if
    end while
End Function

