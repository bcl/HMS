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

'******************************************************
'** Return a list of the Videos and directories
'**
'** Videos end in the following extensions
'** .mp4 .m4v .mov .wmv
'******************************************************
Function displayFiles(files As Object, fileTypes As Object, dirs=false As Boolean) As Object
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
