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
    else if dirType = 4 then
        ret = showMovies( screen, displayList, dir, url )
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
    screen.SetListStyle("flat-category")

    sdImageTypes = []
    sdImageTypes.Push("-SD.jpg")
    sdImageTypes.Push("-SD.png")
    hdImageTypes = []
    hdImageTypes.Push("-HD.jpg")
    hdImageTypes.Push("-HD.png")

    list = CreateObject("roArray", files.Count(), true)
    o = CreateObject("roAssociativeArray")
    o.ContentType = "episode"
    o.ShortDescriptionLine1 = "Setup"
    o.SDPosterURL = "pkg://setup-SD.png"
    o.HDPosterURL = "pkg://setup-HD.png"
    list.Push(o)

    for each f in files
        print f[0]

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
    screen.SetFocusedListItem(1)
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        print msg
        if msg = invalid or msg.isScreenClosed() then
            ' UP appears to close the screen, so we get here
            print "screen closed"
            return invalid
        else if msg.isListItemSelected() then
            if msg.GetIndex() = 0 then
                checkServerUrl(true)
            else
                print "msg: ";msg.GetMessage();" idx: ";msg.GetIndex()
                return files[msg.GetIndex()-1]
            end if
        end if
    end while
End Function

'******************************************************
'** Display a arced-portrait poster screen of items
'** return the one selected by the user or nil?
'******************************************************
Function showMovies( screen As Object, files As Object, dir as Object, url as String ) As Object
    screen.SetListStyle("arced-portrait")

    sdImageTypes = []
    sdImageTypes.Push("-SD.jpg")
    sdImageTypes.Push("-SD.png")
    hdImageTypes = []
    hdImageTypes.Push("-HD.jpg")
    hdImageTypes.Push("-HD.png")

    streamFormat = { mp4 : "mp4", m4v : "mp4", mov : "mp4",
                     wmv : "wmv", hls : "hls"
                   }

    list = CreateObject("roArray", files.Count(), true)
    for each f in files
        print f[0]
        print f[1]

        o = CreateObject("roAssociativeArray")
        o.ContentType = "movie"
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

        if dir.DoesExist(f[1]["basename"]+"-SD.bif") then
            o.SDBifUrl = url+f[1]["basename"]+"-SD.bif"
        end if
        if dir.DoesExist(f[1]["basename"]+"-HD.bif") then
            o.SDBifUrl = url+f[1]["basename"]+"-HD.bif"
        end if

        o.IsHD = false
        o.HDBranded = false
        o.Description = "Should try reading this from a file"
        o.Rating = "NR"
        o.StarRating = 100
        o.Title = f[1]["basename"]
        o.Length = 0

        ' Video related stuff (can I put this all in the same object?)
        o.StreamBitrates = [0]
        o.StreamUrls = [url + f[0]]
        o.StreamQualities = ["SD"]
        if streamFormat.DoesExist(f[1]["extension"].Mid(1)) then
            o.StreamFormat = streamFormat[f[1]["extension"].Mid(1)]
            print o.StreamFormat
        else
            o.StreamFormat = ["mp4"]
        end if

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
            ' If the selected entry is a directory, return it
            if (files[msg.GetIndex()][0].Right(1) = "/")
                return files[msg.GetIndex()]
            else
                ' If it is a movie, play it
                playMovie(list[msg.GetIndex()])
            end if
        end if
    end while
End Function


'******************************************************
'** Play the video using the data from the movie
'** metadata object passed to it
'******************************************************
Sub playMovie( movie as Object)
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)

    video.SetContent(movie)
    video.show()

    lastPos = 0
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                print "Closing video screen"
                exit while
            else if msg.isPlaybackPosition() then
                lastPos = msg.GetIndex()
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while

    ' Save the last played position someplace

End Sub

