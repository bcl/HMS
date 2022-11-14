'********************************************************************
'**  Home Media Server Application - MainScene
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "MainScene->Init()"
    m.top.ObserveField("serverurl", "RunContentTask")

    url = RegRead("ServerURL")
    if url = invalid then
        RunSetupServerDialog("")
    else
        ' Validate the url
        RunValidateURLTask(url)
    end if
end sub


sub RunContentTask()
    print "MainScene->RunContentTask()"

    m.contentTask = CreateObject("roSGNode", "MainLoaderTask")
    m.contentTask.serverurl = m.top.serverurl
    m.contentTask.ObserveField("categories", "OnCategoriesLoaded")
    m.contentTask.control = "run"
end sub

sub OnCategoriesLoaded()
    print "MainScene->OnCategoriesLoaded()"
    print m.contentTask.categories
    m.categories = m.contentTask.categories

    ' Add these to the list on the left side of the screen... how?
    m.panels = m.top.FindNode("panels")
    m.listPanel = m.panels.CreateChild("ListPanel")
    m.listPanel.observeField("createNextPanelIndex", "OnCreateNextPanelIndex")

    m.labelList = CreateObject("roSGNode", "LabelList")
    m.labelList.observeField("focusedItem", "OnLabelListSelected")
    m.listPanel.list = m.labelList
    m.listPanel.appendChild(m.labelList)
    m.listPanel.SetFocus(true)

    ln = CreateObject("roSGNode", "ContentNode")
    for each item in m.categories:
        n = CreateObject("roSGNode", "ContentNode")
        n.title = item
        ln.appendChild(n)
    end for
    m.labelList.content = ln
end sub

sub OnCreateNextPanelIndex()
    print "MainScene->OnCreateNextPanelIndex()"
    print m.listPanel.createNextPanelIndex
end sub

sub OnLabelListSelected()
    print "MainScene->OnLabelListSelected()"
end sub

sub RunValidateURLTask(url as string)
    print "MainScene->RunValidateURLTask()"

    m.validateTask = CreateObject("roSGNode", "ValidateURLTask")
    m.validateTask.serverurl = url
    m.validateTask.ObserveField("valid", "OnValidateChanged")
    m.validateTask.control = "run"
end sub

sub OnValidateChanged()
    print "MainScene->OnValidateChanged"
    print m.validateTask.serverurl
    print m.validateTask.valid
    if not m.validateTask.valid then
        ' Still invalid, run it again
        RunSetupServerDialog(m.validateTask.serverurl)
    else
        ' Valid url, trigger the content load
        m.top.serverurl = m.validateTask.serverurl
        ' And save it for next time
        RegWrite("ServerURL", m.validateTask.serverurl)
        m.top.keystore = m.validateTask.keystore
    end if
end sub

sub RunSetupServerDialog(url as string)
    print "MainScene->RunSetupServerDialog()"
    m.serverDialog = createObject("roSGNode", "SetupServerDialog")
    m.serverDialog.ObserveField("serverurl", "OnSetupServerURL")
    m.serverDialog.text = url
    m.top.dialog = m.serverDialog
end sub

sub OnSetupServerURL()
    print "MainScene->OnSetupServerURL()"
    print m.serverDialog.serverurl

    RunValidateURLTask(m.serverDialog.serverurl)
end sub
