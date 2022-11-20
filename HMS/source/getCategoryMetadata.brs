'********************************************************************
'**  Home Media Server Application - Get the metadata for a category
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************

'*******************************************************************
' Return a roArray of ContentNodes for the selected category
' The list is sorted by title, and the ContentNode has the fields
' setup for direct use with the VideoNode
'
' Pass the server url and the category (the subdirectory) to get the
' metadata from.
'*******************************************************************
Function getCategoryMetadata(url As String, category As String) As Object
    cat_url = url + "/" + category + "/"
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

'*********************************
' Return the type of the directory
'
' 1 = photos
' 2 = songs
' 3 = episodes
' 4 = movies
'*********************************
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

'**************************************************************
' Get the poster name for the content type
'
' First look for a specific .png or .jpg matching the basename,
' then try 'default'
'
' Pass the full listing hash, the server url, basename of the
' video, and content type. eg. SD, HD, FHD
'
' It returns the full url to the poster to use or "" if none
' are found in the listing.
'**************************************************************
Function GetPosterURL(listing_hash as Object, url as String, basename as String, content as String) as String
    if listing_hash.DoesExist(basename+"-"+content+".png") then
        return url+basename+"-"+content+".png"
    else if listing_hash.DoesExist(basename+"-"+content+".jpg") then
        return url+basename+"-"+content+".jpg"
    else if listing_hash.DoesExist("default-"+content+".png") then
        return url+"default-"+content+".png"
    else if listing_hash.DoesExist("default-"+content+".jpg") then
        return url+"default-"+content+".jpg"
    end if

    return ""
End Function

'************************************************************
' Get the bif file url for the content type
'
' Pass the full listing hash, the server url, basename of the
' video, and content type. eg. SD, HD, FHD
'
' It returns the full url to the bif file or "" if none are
' found in the listing.
'************************************************************
Function GetBifURL(listing_hash as Object, url as String, basename as String, content as String) as String
    if listing_hash.DoesExist(basename+"-"+content+".bif") then
        return url+basename+"-"+content+".bif"
    end if

    return ""
End Function

'*****************************************************
' Create an object with the movie metadata
'
' Return a ContentNode with all the fields
' needed for use with the VideoNode setup.
'
' Pass the filename, server url, and full listing_hash
'*****************************************************
Function MovieObject(file As Object, url As String, listing_hash as Object) As Object
    o = CreateObject("roSGNode", "ContentNode")
    o.ContentType = "movie"
    o.ShortDescriptionLine1 = file[1]["basename"]

' XXX says no field in ContentNode
'    o.IsHD = false

    ' Assume there is always a SD poster
    o.SDPosterURL = GetPosterURL(listing_hash, url, file[1]["basename"], "SD")

    ' Fall back to lower existing poster for HD and FHD if they don't exist
    o.HDPosterURL = GetPosterURL(listing_hash, url, file[1]["basename"], "HD")
    if o.HDPosterURL = ""
        o.HDPosterURL = o.SDPosterURL
    end if
    o.FHDPosterURL = GetPosterURL(listing_hash, url, file[1]["basename"], "FHD")
    if o.FHDPosterURL = ""
        if o.HDPosterURL <> ""
            o.FHDPosterURL = o.HDPosterURL
        else
            o.FHDPosterURL = o.SDPosterURL
        end if
    end if

    ' Setup the .bif files
    o.SDBifURL = GetBifURL(listing_hash, url, file[1]["basename"], "SD")
    o.HDBifURL = GetBifURL(listing_hash, url, file[1]["basename"], "HD")
    o.FHDBifURL = GetBifURL(listing_hash, url, file[1]["basename"], "FHD")

' NOTE: Cannot easily just read a file in this function
'    if listing_hash.DoesExist(file[1]["basename"]+".txt") then
'        o.Description = getDescription(url+file[1]["basename"]+".txt")
'    end if

    o.HDBranded = false
    o.Rating = "NR"
    o.StarRating = 100
    o.Title = file[1]["basename"]
    o.Url = url + file[0]

    streamFormat = { mp4 : "mp4", m4v : "mp4", mov : "mp4",
                     wmv : "wmv", hls : "hls"
                   }
    if streamFormat.DoesExist(file[1]["extension"].Mid(1)) then
        o.StreamFormat = streamFormat[file[1]["extension"].Mid(1)]
    else
        o.StreamFormat = "mp4"
    end if

    return o
End Function
