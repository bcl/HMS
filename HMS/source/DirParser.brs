' ********************************************************************
' **  Parse an HTML directory listing
' **  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
' ********************************************************************

Sub MainTest()
    http = CreateObject("roUrlTransfer")
    http.SetUrl("http://wyatt.brianlane.com/")
    dir = http.GetToString()

    ' Try parsing as if it is XML
    rsp=CreateObject("roXMLElement")
    if not rsp.Parse(dir) then
        print "Cannot parse directory listing as XML"
        stop
    end if
    ' grab all the <a href /> elements
    urls = GetUrls([], rsp)
    print urls
End Sub

Sub GetUrls(array as Object, element as Object) As Object
    if element.GetName() = "a" and element.HasAttribute("href") then
        array.Push(element.GetAttributes()["href"])
    end if
    if element.GetChildElements()<>invalid then
        for each e in element.GetChildElements()
            GetUrls(array, e)
        end for
    end if
    return array
End Sub

