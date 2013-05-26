'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2010-2013 Brian C. Lane All Rights Reserved.
'********************************************************************

'******************************************************
' Display a scrolling grid of everything on the server
'******************************************************
Function displayDirectory( url As String ) As Object
    print "url: ";url

    port=CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")
    grid.SetMessagePort(port)
    grid.SetDisplayMode("scale-to-fit")

    ' Build list of Category Names from the top level directories
    listing = getDirectoryListing(url)
    if listing = invalid then
        print "Failed to get directory listing for ";url
        return invalid
    end if
    categories = displayFiles(listing, {}, true)
    Sort(categories, function(k)
                       return LCase(k[0])
                     end function)

    ' Setup Grid with categories
    titles = CreateObject("roArray", categories.Count(), false)
    for i = 0 to categories.Count()-1
        print "Category: :";categories[i][0]
        titles.Push(getLastElement(categories[i][0]))
    end for
    grid.SetupLists(titles.Count())
    grid.SetListNames(titles)

    ' run the grid
    showTimeBreadcrumb(grid)
    grid.Show()

    ' Hold all the movie objects
    screen = CreateObject("roArray", categories.Count(), false)
    ' Setup each category's list
    for i = 0 to categories.Count()-1
        cat_url = url + "/" + categories[i][0]
        listing = getDirectoryListing(cat_url)
        ' What kind of directory is this?
        dirType = directoryType(listing)
        if dirType = 1 then
            displayList  = displayFiles(listing, { jpg : true })
        else if dirType = 2 then
            displayList = displayFiles(listing, { mp3 : true })
        else if dirType = 3 then
            displayList = displayFiles(listing, { mp4 : true, m4v : true, mov : true, wmv : true } )
        else if dirType = 4 then
            displayList = displayFiles(listing, { mp4 : true, m4v : true, mov : true, wmv : true } )
        end if
        if dirType <> 0 then
            Sort(displayList, function(k)
                               return LCase(k[0])
                             end function)
            list = CreateObject("roArray", displayList.Count(), false)
            for j = 0 to displayList.Count()-1
                list.Push(MovieObject(displayList[j], cat_url, listing))
            end for
            grid.SetContentList(i, list)
            screen.Push(list)
        else
            grid.SetContentList(i, [])
            screen.Push([])
        end if
    end for

    while true
        msg = wait(30000, port)
        if type(msg) = "roGridScreenEvent" then
            if msg.isScreenClosed() then
                return -1
            elseif msg.isListItemFocused()
                print "Focused msg: ";msg.GetMessage();"row: ";msg.GetIndex();
                print " col: ";msg.GetData()
            elseif msg.isListItemSelected()
                print "Selected msg: ";msg.GetMessage();"row: ";msg.GetIndex();
                print " col: ";msg.GetData()

                playMovie(screen[msg.GetIndex()][msg.GetData()])
            endif
        else if msg = invalid then
            showTimeBreadcrumb(grid)
        endif
    end while
End Function

' Put this into utils
Function getLastElement(url As String) As String
    ' Get last element of URL
    toks = url.tokenize("/")
    return toks[toks.Count()-1]
End Function

Function directoryType(listing As Object) As Integer
    for i = 0 to listing.Count()-1
        if listing[i] = "photos" then
            return 1
        else if listing[i] = "songs" then
            return 2
        else if listing[i] = "episodes" then
            return 3
        else if listing[i] = "movies" then
            return 4
        end if
    end for
    return 0
End Function


Function MovieObject(file As Object, url As String, listing as Object) As Object
    o = CreateObject("roAssociativeArray")
    o.ContentType = "movie"
    o.ShortDescriptionLine1 = file[1]["basename"]

    ' Default images
    o.SDPosterUrl = url+"default-SD.png"
    o.HDPosterUrl = url+"default-HD.png"

    ' Search for SD & HD images and .bif files
    for i = 0 to listing.Count()-1
        if Instr(1, listing[i], file[1]["basename"]) = 1 then
            if fileEndsWith(file[1]["basename"], listing[i], ["-SD.png", "-SD.jpg"]) then
                o.SDPosterUrl = url+listing[i]
            else if fileEndsWith(file[1]["basename"], listing[i], ["-HD.png", "-HD.jpg"]) then
                o.HDPosterUrl = url+listing[i]
            else if fileEndsWith(file[1]["basename"], listing[i], ["-SD.bif"]) then
                o.SDBifUrl = url+listing[i]
            else if fileEndsWith(file[1]["basename"], listing[i], ["-HD.bif"]) then
                o.HDBifUrl = url+listing[i]
            else if fileEndsWith(file[1]["basename"], listing[i], [".txt"]) then
                o.Description = getDescription(url+listing[i])
            end if
        end if
    end for
    o.IsHD = false
    o.HDBranded = false
    o.Rating = "NR"
    o.StarRating = 100
    o.Title = file[1]["basename"]
    o.Length = 0

    ' Video related stuff (can I put this all in the same object?)
    o.StreamBitrates = [0]
    o.StreamUrls = [url + file[0]]
    o.StreamQualities = ["SD"]

    streamFormat = { mp4 : "mp4", m4v : "mp4", mov : "mp4",
                     wmv : "wmv", hls : "hls"
                   }
    if streamFormat.DoesExist(file[1]["extension"].Mid(1)) then
        o.StreamFormat = streamFormat[file[1]["extension"].Mid(1)]
    else
        o.StreamFormat = ["mp4"]
    end if

    return o
End Function

' Set breadcrumb to current time
Function showTimeBreadcrumb(screen As Object)
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    if hour < 12 then
        ampm = " AM"
    else
        ampm = " PM"
        if hour > 12 then
            hour = hour - 12
        end if
    end if
    hour = tostr(hour)
    minutes = now.GetMinutes()
    if minutes < 10 then
        minutes = "0"+tostr(minutes)
    else
        minutes = tostr(minutes)
    end if
    bc = now.AsDateStringNoParam()+" "+hour+":"+minutes+ampm
    screen.SetBreadcrumbText(bc, "")
End Function

' Get the last position for the movie
Function getLastPosition(movie As Object) As Integer
    ' use movie.Title as the filename
    lastPos = ReadAsciiFile("tmp:/"+movie.Title)
    print "Last position of ";movie.Title;" is ";lastPos
    if lastPos <> "" then
        return strtoi(lastPos)
    end if
    return 0
End Function

'******************************************************
'** Show the contents of url
'******************************************************
Function displayDirectoryOld( url As String ) As Object
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
    else if dirType = 3 then
        ret = showVideos( screen, displayList, dir, url, true)
    else if dirType = 4 then
        ret = showVideos( screen, displayList, dir, url, false )
    else
        return invalid
    end if
    return ret
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

'**************************************************************
'** Return true if the filename ends with any of the extensions
'**************************************************************
Function fileEndsWith(basename As String, filename As String, extensions As Object) As Boolean
    for each e in extensions
        if basename+e = filename
            return true
        end if
    end for
    return false
End Function

'******************************************************
'** Display a flat-category poster screen of items
'** return the one selected by the user or nil?
'******************************************************
Function showCategories( screen As Object, files As Object, dir as Object, url as String ) As Object
    screen.SetListStyle("flat-category")

    list = CreateObject("roArray", files.Count(), true)
    o = CreateObject("roAssociativeArray")
    o.ContentType = "episode"
    o.ShortDescriptionLine1 = "Setup"
'    o.SDPosterURL = getPosterUrl( dir, url, "Setup", "Setup", "-SD" )
'    o.HDPosterURL = getPosterUrl( dir, url, "Setup", "Setup", "-HD" )
    list.Push(o)

    for each f in files
        print f[0]

        o = CreateObject("roAssociativeArray")
        o.ContentType = "episode"
        o.ShortDescriptionLine1 = f[1]["basename"]

        o.SDPosterUrl = getPosterUrl( dir, url, f[1]["basename"], "dir", "-SD" )
        o.HDPosterUrl = getPosterUrl( dir, url, f[1]["basename"], "dir", "-HD" )

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
'** Display a arced-portrait or flat-episodic poster
'** screen of items
'** Handle playback of selected video
'******************************************************
Function showVideos( screen As Object, files As Object, dir as Object, url as String, episodes As Boolean ) As Object
    if episodes then
        screen.SetListStyle("flat-episodic")
    else
        screen.SetListStyle("arced-portrait")
    end if

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

        o.SDPosterUrl = getPosterUrl( dir, url, f[1]["basename"], "dir", "-SD" )
        o.HDPosterUrl = getPosterUrl( dir, url, f[1]["basename"], "dir", "-HD" )

        if dir.DoesExist(f[1]["basename"]+"-SD.bif") then
            o.SDBifUrl = url+f[1]["basename"]+"-SD.bif"
        end if
        if dir.DoesExist(f[1]["basename"]+"-HD.bif") then
            o.SDBifUrl = url+f[1]["basename"]+"-HD.bif"
        end if

        o.IsHD = false
        o.HDBranded = false
        o.Description = getDescription(f[1]["basename"], url, dir)
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
Sub playMovie(movie as Object)
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetPositionNotificationPeriod(15)

    movie.PlayStart = getLastPosition(movie)
    video.SetContent(movie)
    video.show()

    lastPos = 0
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                exit while
            else if msg.isPlaybackPosition() then
                lastPos = msg.GetIndex()
                WriteAsciiFile("tmp:/"+movie.Title, tostr(lastPos))
            else if msg.isfullresult() then
                DeleteFile("tmp:/"+movie.Title)
            else if msg.isRequestFailed() then
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
End Sub

'******************************************************
'** Check to see if a description file (.txt) exists
'** and read it into a string.
'** And if it is missing return ""
'******************************************************
Function getDescription(url As String)
    print "Retrieving description from ";url
    http = CreateObject("roUrlTransfer")
    http.SetUrl(url)
    resp = http.GetToString()

    if resp <> invalid then
        return resp
    end if
    return ""
End Function

