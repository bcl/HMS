'********************************************************************
'**  Home Media Server Application - MainLoaderTask
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "MainLoaderTask->Init()"

    m.top.functionName = "GetContent"
end sub

' GetContent is executed when  m.contentTask.control = "run" from MainScene
sub GetContent()
    print "MainLoaderTask->GetContent()"
    print m.top.serverurl

    m.top.categories = getSortedCategoryTitles(m.top.serverurl)
end sub

'******************************************************
' Return a roArray of just the category names
'******************************************************
Function catTitles(categories As Object) As Object
    titles = CreateObject("roArray", categories.Count(), false)
    for i = 0 to categories.Count()-1
        titles.Push(getLastElement(categories[i][0]))
    end for
    return titles
End Function

'******************************************************
'** Get a sorted roArray of category titles
'******************************************************
Function getSortedCategoryTitles(url as String) As Object
     ' Build list of Category Names from the top level directories
     listing = getDirectoryListing(url)
     if listing = invalid then
         return invalid
     end if
     categories = displayFiles(listing, {}, true)
     Sort(categories, function(k)
                        return LCase(k[0])
                      end function)
    return catTitles(categories)
End Function
