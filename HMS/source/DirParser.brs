' ********************************************************************
' **  Parse an HTML directory listing
' **  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
' ********************************************************************

Sub Main()
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

Sub PrintXML(element As Object, depth As Integer)
    print tab(depth*3);"Name: ";element.GetName()
    if not element.GetAttributes().IsEmpty() then
        print tab(depth*3);"Attributes: ";
        for each a in element.GetAttributes()
            print a;"=";left(element.GetAttributes()[a], 20);
            if element.GetAttributes().IsNext() then print ", ";
        end for
        print
    end if
    if element.GetText()<>invalid then
        print tab(depth*3);"Contains Text: ";left(element.GetText(), 40)
    end if
    if element.GetChildElements()<>invalid
        print tab(depth*3);"Contains roXMLList:"
        for each e in element.GetChildElements()
            PrintXML(e, depth+1)
        end for
    end if
    print
end sub


