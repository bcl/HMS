'********************************************************************
'**  Home Media Server Application - MainScene
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "MainScene->Init()"

    RunContentTask()

end sub


sub RunContentTask()
    print "MainScene->RunContentTask()"

    m.contentTask = CreateObject("roSGNode", "MainLoaderTask")
    m.contentTask.ObserveField("content", "OnMainContentLoaded")
    m.contentTask.control = "run"
end sub

sub OnMainContentLoaded()
    print "MainScene->OnMainContentLoaded()"

'    m.GridScreen.SetFocus(true)
'    m.loadingIndicator.visible = false
'    m.GridScreen.content = m.contentTask.content
end sub
