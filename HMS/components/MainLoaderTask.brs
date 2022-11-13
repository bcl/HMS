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

end sub
