'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2010-2013 Brian C. Lane All Rights Reserved.
'********************************************************************

'******************************************************
'** Display a scrolling grid of everything on the server
'******************************************************
Function mediaServer( url As String, has_keystore As Boolean ) As Object
    print "url: ";url
    print "has_keystore: "; has_keystore

    port = CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)
    screen.SetListStyle("arced-portrtait")
    screen.setListDisplayMode("scale-to-fit")

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
    titles = catTitles(categories)
    screen.SetListNames(titles)
    max_titles = titles.Count()-1

    screen.SetFocusToFilterBanner(true)
    last_title = getFocusedItem(url, has_keystore, "filter_pos", max_titles)
    screen.SetFocusedList(last_title)
    showTimeBreadcrumb(screen, true)
    screen.Show()

    cache = CreateObject("roAssociativeArray")

    ' Load the selected title
    metadata = getCategoryMetadata(url, categories[last_title][0])
    if metadata.Count() > 0 then
        cache.AddReplace(tostr(last_title), metadata)
        screen.SetContentList(metadata)
        screen.SetFocusedListItem(getFocusedItem(url, has_keystore, titles[last_title], metadata.Count()))
    end if

    setup_selected = false
    while true
        msg = wait(30000, port)
        if type(msg) = "roPosterScreenEvent" then
            if msg.isScreenClosed() then
                return -1
            elseif msg.isListSelected()
                if msg.GetIndex() = max_titles then
                    screen.SetContentList(getSetupRow(url))
                    setup_selected = true
                else
                    setup_selected = false
                    last_title = msg.GetIndex()
                    print "selected "; titles[last_title]

                    ' Save this as the last selected filter position
                    if has_keystore = true then
                        setKeyValue(url, "filter_pos", tostr(msg.GetIndex()))
                    end if
                    screen.SetContentList([])

                    ' Is this cached? If not, clear it and look it up
                    if not cache.DoesExist(tostr(last_title)) then
                        metadata = getCategoryMetadata(url, categories[last_title][0])
                        cache.AddReplace(tostr(last_title), metadata)
                    else
                        metadata = cache.Lookup(tostr(last_title))
                    end if
                    screen.SetContentList(metadata)
                    screen.SetFocusedListItem(getFocusedItem(url, has_keystore, titles[last_title], metadata.Count()))
                end if
            elseif msg.isListItemSelected() and setup_selected = true then
                checkServerUrl(true)
                screen.SetFocusToFilterBanner(true)
            elseif msg.isListItemSelected()
                if has_keystore = true then
                    setKeyValue(url, titles[last_title], tostr(msg.GetIndex()))
                end if
                movies = screen.GetContentList()
                print movies[msg.GetIndex()]
                result = playMovie(movies[msg.GetIndex()], url, has_keystore)
                if result = true and msg.GetIndex() < movies.Count() then
                    ' Advance to the next video and save it
                    screen.SetFocusedListItem(msg.GetIndex()+1)
                    if has_keystore = true then
                        if msg.GetIndex() < movies.Count() then
                            setKeyValue(url, titles[last_title], tostr(msg.GetIndex()+1))
                        end if
                    end if
                end if
                showTimeBreadcrumb(screen, true)
            end if
        else if msg = invalid then
            showTimeBreadcrumb(screen, true)
        endif
    end while
End Function


'*************************************
'** Get the Setup row
'*************************************
Function getSetupRow(url As String) As Object
    ' Setup the Search
    setup = CreateObject("roArray", 1, true)
    o = CreateObject("roAssociativeArray")
    o.ContentType = "episode"
    o.Title = "Setup"
    o.SDPosterUrl = url+"/Setup-SD.png"
    o.HDPosterUrl = url+"/Setup-HD.png"
    setup.Push(o)
    return setup
End Function

'**********************************
'** Return the type of the directory
'**********************************
Function directoryType(listing_hash As Object) As Integer
    if listing_hash.DoesExist("photos") then
        return 1
    else if listing_hash.DoesExist("songs") then
        return 2
    else if listing_hash.DoesExist("episodes") then
        return 3
    else if listing_hash.DoesExist("movies") then
        return 4
    end if
    return 0
End Function


'******************************************
'** Create an object with the movie metadata
'******************************************
Function MovieObject(file As Object, url As String, listing_hash as Object) As Object
    o = CreateObject("roAssociativeArray")
    o.ContentType = "movie"
    o.ShortDescriptionLine1 = file[1]["basename"]

    ' Search for SD & HD images and .bif files
    if listing_hash.DoesExist(file[1]["basename"]+"-SD.png") then
        o.SDPosterUrl = url+file[1]["basename"]+"-SD.png"
    else if listing_hash.DoesExist(file[1]["basename"]+"-SD.jpg") then
        o.SDPosterUrl = url+file[1]["basename"]+"-SD.jpg"
    else
        o.SDPosterUrl = url+"default-SD.png"
    end if

    o.IsHD = false
    ' With the roPosterScreen it always wants to request the HDPosterURL, no matter what IsHD is set to.
    ' So Fake it out and reuse the -SD images for now.
    if listing_hash.DoesExist(file[1]["basename"]+"-SD.png") then
        o.HDPosterUrl = url+file[1]["basename"]+"-SD.png"
    else if listing_hash.DoesExist(file[1]["basename"]+"-SD.jpg") then
        o.HDPosterUrl = url+file[1]["basename"]+"-SD.jpg"
    else
        o.HDPosterUrl = url+"default-SD.png"
    end if

    ' Setup the .bif file
    if listing_hash.DoesExist(file[1]["basename"]+"-SD.bif") then
        o.SDBifUrl = url+file[1]["basename"]+"-SD.bif"
    end if
    if listing_hash.DoesExist(file[1]["basename"]+"-HD.bif") then
        o.HDBifUrl = url+file[1]["basename"]+"-HD.bif"
    end if

    if listing_hash.DoesExist(file[1]["basename"]+".txt") then
        o.Description = getDescription(url+file[1]["basename"]+".txt")
    end if

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

'********************************
'** Set breadcrumb to current time
'********************************
Function showTimeBreadcrumb(screen As Object, use_ampm As Boolean)
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    if use_ampm then
        if hour < 12 then
            ampm = " AM"
        else
            ampm = " PM"
            if hour > 12 then
                hour = hour - 12
            end if
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

'*************************************
'** Get the last position for the movie
'*************************************
Function getLastPosition(title As String, url As String, has_keystore As Boolean) As Integer
    ' use movie.Title as the filename
    last_pos = ReadAsciiFile("tmp:/"+title)
    if last_pos <> "" then
        return last_pos.toint()
    end if
    ' No position stored on local filesystem, query keystore
    if has_keystore = true then
        last_pos = getKeyValue(url, title)
        if last_pos <> "" then
            return last_pos.toint()
        end if
    end if
    return 0
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
'** Play the video using the data from the movie
'** metadata object passed to it
'******************************************************
Sub playMovie(movie As Object, url As String, has_keystore As Boolean) As Boolean
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetPositionNotificationPeriod(15)

    movie.PlayStart = getLastPosition(movie.Title, url, has_keystore)
    video.SetContent(movie)
    video.show()

    last_pos = 0
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                exit while
            else if msg.isPlaybackPosition() then
                last_pos = msg.GetIndex()
                WriteAsciiFile("tmp:/"+movie.Title, tostr(last_pos))
                if has_keystore = true then
                    setKeyValue(url, movie.Title, tostr(last_pos))
                end if
            else if msg.isfullresult() then
                DeleteFile("tmp:/"+movie.Title)
                if has_keystore = true then
                    setKeyValue(url, movie.Title, "")
                end if
                return true
            else if msg.isRequestFailed() then
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while

    return false
End Sub

'******************************************************
'** Check to see if a description file (.txt) exists
'** and read it into a string.
'** And if it is missing return ""
'******************************************************
Function getDescription(url As String)
    http = CreateObject("roUrlTransfer")
    http.SetUrl(url)
    resp = http.GetToString()

    if resp <> invalid then
        return resp
    end if
    return ""
End Function

'******************************************************
' Return a roArray of just the category names
'******************************************************
Function catTitles(categories As Object) As Object
    titles = CreateObject("roArray", categories.Count()+1, false)
    for i = 0 to categories.Count()-1
        titles.Push(getLastElement(categories[i][0]))
    end for
    titles.Push("Setup")
    return titles
End Function

'*******************************************************************
' Return a roArray of roAssociativeArrays for the selected category
'*******************************************************************
Function getCategoryMetadata(url As String, category As String) As Object
    cat_url = url + "/" + category
    listing = getDirectoryListing(cat_url)
    listing_hash = CreateObject("roAssociativeArray")
    for each f in listing
        listing_hash.AddReplace(f, "")
    end for

    ' What kind of directory is this?
    dirType = directoryType(listing_hash)
    if dirType = 1 then
        displayList  = displayFiles(listing, { jpg : true })
    else if dirType = 2 then
        displayList = displayFiles(listing, { mp3 : true })
    else if dirType = 3 then
        displayList = displayFiles(listing, { mp4 : true, m4v : true, mov : true, wmv : true } )
    else if dirType = 4 then
        displayList = displayFiles(listing, { mp4 : true, m4v : true, mov : true, wmv : true } )
    else
        ' Assume movies if there is no type file
        displayList = displayFiles(listing, { mp4 : true, m4v : true, mov : true, wmv : true } )
    end if

    Sort(displayList, function(k)
                       return LCase(k[0])
                     end function)
    list = CreateObject("roArray", displayList.Count(), false)
    for j = 0 to displayList.Count()-1
        list.Push(MovieObject(displayList[j], cat_url, listing_hash))
    end for
    return list
End Function

'******************************************************
' Get the last focused item for a category
' or return 0 if there is no keystore or an error
'******************************************************
Function getFocusedItem(url As String, has_keystore As Boolean, category As String, max_items As Integer) As Integer
    if has_keystore = true then
        focus_pos = getKeyValue(url, category)
        if focus_pos <> "" and focus_pos.toint() < max_items then
            print "category ";category;" focus is ";focus_pos.toint()
            return focus_pos.toint()
        end if
    end if
    print "category ";category;" focus is 0"
    return 0
End Function
