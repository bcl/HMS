'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
'********************************************************************

'******************************************************
'** Show the contents of url
'******************************************************
Sub displayDirectory( url ) As Void

    ' Get the directory listing
    listing = getDirectoryListing(url)
    if listing = invalid then
        print "Failed to get directory listing for"; url
        return
    end if

    print listing

End Sub

