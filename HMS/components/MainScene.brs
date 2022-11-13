'********************************************************************
'**  Home Media Server Application - MainScene
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "MainScene->Init()"
    m.top.ObserveField("serverurl", "RunContentTask")

    RunSetupServerDialog()

end sub


sub RunContentTask()
    print "MainScene->RunContentTask()"

    m.contentTask = CreateObject("roSGNode", "MainLoaderTask")
    m.contentTask.serverurl = m.top.serverurl
    m.contentTask.ObserveField("content", "OnMainContentLoaded")
    m.contentTask.control = "run"
end sub

sub OnMainContentLoaded()
    print "MainScene->OnMainContentLoaded()"

'    m.GridScreen.SetFocus(true)
'    m.loadingIndicator.visible = false
'    m.GridScreen.content = m.contentTask.content
end sub

sub RunSetupServerDialog()
    print "MainScene->RunSetupServerDialog()"
    m.serverDialog = createObject("roSGNode", "SetupServerDialog")
    m.serverDialog.ObserveField("serverurl", "OnSetupServerURL")
    m.top.dialog = m.serverDialog
end sub

sub OnSetupServerURL()
    print "MainScene->OnSetupServerURL()"
    print m.serverDialog.serverurl

    ' pretend it was ok
    m.top.serverurl = m.serverDialog.serverurl
end sub
