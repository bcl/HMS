'**********************************************************
'**  Video Player Example Application - Show Feed 
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

'******************************************************
'** Set up the show feed connection object
'** This feed provides the detailed list of shows for
'** each subcategory (categoryLeaf) in the category
'** category feed. Given a category leaf node for the
'** desired show list, we'll hit the url and get the
'** results.     
'******************************************************

Function InitShowFeedConnection(category As Object) As Object

    if validateParam(category, "roAssociativeArray", "initShowFeedConnection") = false return invalid 

    conn = CreateObject("roAssociativeArray")
    conn.UrlShowFeed  = category.feed 

    conn.Timer = CreateObject("roTimespan")

    conn.LoadShowFeed    = load_show_feed
    conn.ParseShowFeed   = parse_show_feed
    conn.InitFeedItem    = init_show_feed_item

    print "created feed connection for " + conn.UrlShowFeed
    return conn

End Function


'******************************************************
'Initialize a new feed object
'******************************************************
Function newShowFeed() As Object

    o = CreateObject("roArray", 100, true)
    return o

End Function


'***********************************************************
' Initialize a ShowFeedItem. This sets the default values
' for everything.  The data in the actual feed is sometimes
' sparse, so these will be the default values unless they
' are overridden while parsing the actual game data
'***********************************************************
Function init_show_feed_item() As Object
    o = CreateObject("roAssociativeArray")

    o.ContentId        = ""
    o.Title            = ""
    o.ContentType      = ""
    o.Description      = ""
    o.Length           = ""
	o.Actors           = CreateObject("roArray", 3, true)
	o.Director         = CreateObject("roArray", 1, true)
	o.Categories	   = CreateObject("roArray", 3, true)
    o.StreamFormats    = CreateObject("roArray", 5, true) 
    o.StreamQualities  = CreateObject("roArray", 5, true) 
    o.StreamBitrates   = CreateObject("roArray", 5, true)
    o.StreamUrls       = CreateObject("roArray", 5, true)

    return o
End Function


'*************************************************************
'** Grab and load a show detail feed. The url we are fetching 
'** is specified as part of the category provided during 
'** initialization. This feed provides a list of all shows
'** with details for the given category feed.
'*********************************************************
Function load_show_feed(conn As Object) As Dynamic

    if validateParam(conn, "roAssociativeArray", "load_show_feed") = false return invalid 

    print "url: " + conn.UrlShowFeed 
    http = NewHttp(conn.UrlShowFeed)

    m.Timer.Mark()
    rsp = http.GetToStringWithRetry()
    print "Request Time: " + itostr(m.Timer.TotalMilliseconds())

    feed = newShowFeed()
    xml=CreateObject("roXMLElement")
    if not xml.Parse(rsp) then
        print "Can't parse feed"
		print rsp
        return feed
    endif

    if xml.GetName() <> "feed" then
        print "no feed tag found"
        return feed
    endif

    if islist(xml.GetBody()) = false then
        print "no feed body found"
        return feed
    endif

    m.Timer.Mark()
    m.ParseShowFeed(xml, feed)
    print "Show Feed Parse Took : " + itostr(m.Timer.TotalMilliseconds())

    return feed

End Function


'**************************************************************************
'**************************************************************************
Function parse_show_feed(xml As Object, feed As Object) As Void

    showCount = 0
    showList = xml.GetChildElements()

    for each curShow in showList

        'for now, don't process meta info about the feed size
        if curShow.GetName() = "resultLength" or curShow.GetName() = "endIndex" then
            goto skipitem
        endif

        item = init_show_feed_item()

        'fetch all values from the xml for the current show
        item.HDPosterUrl      = validstr(curShow@hdPosterUrl) 
        item.SDPosterUrl      = validstr(curShow@sdPosterUrl) 
        item.ContentId        = validstr(curShow.contentId.GetText()) 
        item.Title            = validstr(curShow.title.GetText()) 
        item.Description      = validstr(curShow.description.GetText()) 
        item.ContentType      = validstr(curShow.contentType.GetText())
        item.ContentQuality   = validstr(curShow.contentQuality.GetText())
        item.Length           = strtoi(validstr(curShow.length.GetText()))
        item.HDBifUrl         = validstr(curShow.hdBifUrl.GetText())
        item.SDBifUrl         = validstr(curShow.sdBifUrl.GetText())
		item.StreamFormat     = validstr(curShow.streamFormat.GetText())
		item.ReleaseDate      = validstr(curshow.releaseDate.GetText())
		item.Rating           = validstr(curshow.rating.GetText())
		item.StarRating       = validstr(curshow.starRating.GetText())
		item.UserStarRating   = validstr(curshow.userStarRating.GetText())
        item.ShortDescriptionLine1 = validstr(curshow.ShortDescriptionLine1.GetText())
        item.ShortDescriptionLine2 = validstr(curshow.ShortDescriptionLine2.GetText())
		item.EpisodeNumber    = validstr(curshow.episodeNumber.GetText())
		item.HDBranded        = strtobool(validstr(curshow.hdBranded.GetText()))
		item.isHD             = strtobool(validstr(curshow.isHD.GetText()))
		item.TextOverlayUL    = validstr(curshow.textOverlayUL.GetText())
		item.TextOverlayUR    = validstr(curshow.textOverlayUR.GetText())
		item.TextOverlayBody  = validstr(curshow.textOverlayBody.GetText())
		item.Album			  = validstr(curshow.album.GetText())
		item.Artist			  = validstr(curshow.artist.GetText())

        'media may be at multiple bitrates, so parse an build arrays
        for idx = 0 to 4
            e = curShow.media[idx]
            if e  <> invalid then
                item.StreamFormats.Push(validstr(e.streamFormat.GetText()))
                item.StreamBitrates.Push(strtoi(validstr(e.streamBitrate.GetText())))
                item.StreamQualities.Push(validstr(e.streamQuality.GetText()))
                item.StreamUrls.Push(validstr(e.streamUrl.GetText()))
            endif
        next idx

		' May be multiple actors
		for idx = 0 to 2
			e = curShow.actor[idx]
			if e <> invalid then
				item.Actors.Push(validstr(e.GetText()))
			endif
		next idx

		' May be multiple directors
		for idx = 0 to 2
			e = curShow.director[idx]
			if e <> invalid then
				item.Director.Push(validstr(e.GetText()))
			endif
		next idx

		' May be multiple categories
		for idx = 0 to 2
			e = curShow.category[idx]
			if e <> invalid then
				item.Categories.Push(validstr(e.GetText()))
			endif
		next idx
        
        showCount = showCount + 1
        feed.Push(item)

        skipitem:

    next

End Function
