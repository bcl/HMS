'********************************************************************
'**  Home Media Server Application - Get the metadata for a category
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************

'*******************************************************************
' Return a roArray of roAssociativeArrays for the selected category
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


