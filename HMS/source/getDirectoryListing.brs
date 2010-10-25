' ********************************************************************
' **  Parse an HTML directory listing
' **  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
' ********************************************************************
Function getDirectoryListing(url As String) As Object
    print "dir url: ";url

    http = CreateObject("roUrlTransfer")
    http.SetUrl(url)
    dir = http.GetToString()

    if dir = invalid then
        print "Could not get directory listing"
        return invalid
    end if

    ' Try parsing the html as if it is XML
    xml=CreateObject("roXMLElement")
    if not xml.Parse(dir) then
        print "Cannot parse directory listing as XML"
        return invalid
    end if

    print "got xml"

    ' grab all the <a href /> elements
    urls = getUrls({}, xml)

    print urls

    return urls
End Function

Function getUrls(array as Object, element as Object) As Object
    if element.GetName() = "a" and element.HasAttribute("href") then
'        array.AddReplace(element.GetAttributes()["href"], "")
        href = element.GetAttributes()["href"]
        print "href: ";href
        array.AddReplace(href, "")
    end if
    if element.GetChildElements()<>invalid then
        for each e in element.GetChildElements()
            getUrls(array, e)
        end for
    end if
    return array
End Function

