' ********************************************************************
' **  Parse an HTML directory listing
' **  Copyright (c) 2010-2013 Brian C. Lane All Rights Reserved.
' ********************************************************************
Function getDirectoryListing(url As String) As Object
    result = getHTMLWithTimeout(url, 60)

    if result.error then
        title = "Directory Listing Error"
        text  = "There was an error fetching the directory listing."
        print text
        ShowErrorDialog(text, title)

        return invalid
    end if
    dir = result.str

    ' Try parsing the html as if it is XML
    xml=CreateObject("roXMLElement")
    if not xml.Parse(dir) then
        title = "Cannot Parse XML"
        text  = "There was an error parsing the directory listing as XML."
        print text
        ShowErrorDialog(text, title)

        return invalid
    end if

    ' grab all the <a href /> elements
'    urls = getUrls({}, xml)
    return getUrls(CreateObject("roArray", 10, true), xml)
End Function

Function getUrls(array as Object, element as Object) As Object
    if element.GetName() = "a" and element.HasAttribute("href") then
'        array.AddReplace(element.GetAttributes()["href"], "")
        array.Push(element.GetAttributes()["href"])
    end if
    if element.GetChildElements()<>invalid then
        for each e in element.GetChildElements()
            getUrls(array, e)
        end for
    end if
    return array
End Function

