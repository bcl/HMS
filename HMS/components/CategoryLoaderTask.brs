'********************************************************************
'**  Home Media Server Application - CategoryLoaderTask
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "CategoryLoaderTask->Init()"

    m.top.functionName = "GetMetadata"
end sub

' GetMetadata is executed when  m.contentTask.control = "run" from MainScene
sub GetMetadata()
    print "CategoryLoaderTask->GetMetadata()"
    print m.top.serverurl
    print m.top.category

    m.top.metadata = getCategoryMetadata("http://" + m.top.serverurl, m.top.category)
end sub
