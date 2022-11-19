'********************************************************************
'**  Home Media Server Application - MainScene
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "MainScene->Init()"
    m.top.ObserveField("serverurl", "RunContentTask")
    m.details = m.top.FindNode("details")
    m.keystoreTask = CreateObject("roSGNode", "KeystoreTask")

    StartClock()

    url = RegRead("ServerURL")
    if url = invalid then
        RunSetupServerDialog("")
    else
        ' Validate the url
        RunValidateURLTask(url)
    end if

    SetupVideoPlayer()
end sub

sub StartClock()
    m.clock = m.top.FindNode("clock")
    m.clockTimer = m.top.FindNode("clockTimer")
    m.clockTimer.ObserveField("fire", "UpdateClock")
    m.clockTimer.control = "start"
    UpdateClock()
end sub

sub UpdateClock()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    use_ampm = true
    if use_ampm then
        if hour < 12 then
            ampm = " AM"
        else
            ampm = " PM"
            if hour > 12 then
                hour = hour - 12
            end if
        end if
    end if
    hour = tostr(hour)
    minutes = now.GetMinutes()
    if minutes < 10 then
        minutes = "0"+tostr(minutes)
    else
        minutes = tostr(minutes)
    end if
    m.clock.text = now.GetWeekday()+" "+hour+":"+minutes+ampm
end sub

sub RunContentTask()
    print "MainScene->RunContentTask()"

    m.contentTask = CreateObject("roSGNode", "MainLoaderTask")
    m.contentTask.serverurl = m.top.serverurl
    m.contentTask.ObserveField("categories", "OnCategoriesLoaded")
    m.contentTask.control = "run"
end sub

sub GetKeystoreValue(key as string, callback as string)
    m.keystoreTask.serverurl = m.top.serverurl
    m.keystoreTask.key = key
    m.keystoreTask.value = ""
    m.keystoreTask.command = "get"
    if callback <> ""
        m.keystoreTask.ObserveField("done", callback)
    end if
    m.keystoreTask.control = "run"
end sub

sub SetKeystoreValue(key as string, value as string, callback as string)
    m.keystoreTask.serverurl = m.top.serverurl
    m.keystoreTask.key = key
    m.keystoreTask.value = value
    m.keystoreTask.command = "set"
    if callback <> ""
        m.keystoreTask.ObserveField("done", callback)
    end if
    m.keystoreTask.control = "run"
end sub

sub ResetKeystoreTask()
    m.keystoreTask.UNObserveField("done")
    m.keystoreTask.done = false
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
    print m.categories[m.listPanel.createNextPanelIndex]
    m.details.text = ""
    RunCategoryLoadTask(m.categories[m.listPanel.createNextPanelIndex])
end sub

sub RunCategoryLoadTask(category as string)
    print "MainScene->RunCategoryLoadTask()"
    print category

    m.metadataTask = CreateObject("roSGNode", "CategoryLoaderTask")
    m.metadataTask.serverurl = m.top.serverurl
    m.metadataTask.category = category
    m.metadataTask.ObserveField("metadata", "OnMetadataLoaded")
    m.metadataTask.control = "run"
end sub

sub OnMetadataLoaded()
    print "MainScene->OnMetadataLoaded()"
    m.metadata = m.metadataTask.metadata
    if m.metadata = invalid then
        return
    end if
    print "Got "; m.metadataTask.metadata.Count(); " items."

    ' Create one GridPanel and one PosterGrid, then reuse them for each category
    ' This may not be quite right, but it works for now.
    if m.gridPanel = invalid then
        print "Creating new GridPanel"
        m.gridPanel = m.panels.CreateChild("GridPanel")
        m.gridPanel.panelSize = "full"
        m.gridPanel.isFullScreen = true
        m.gridPanel.focusable = true
        m.gridPanel.hasNextPanel = false
        m.gridPanel.createNextPanelOnItemFocus = false

        m.posterGrid = CreateObject("roSGNode", "PosterGrid")
        m.posterGrid.basePosterSize = "[222, 330]"
        m.posterGrid.itemSpacing = "[6, 9]"
        m.posterGrid.posterDisplayMode = "scaleToZoom"
        m.posterGrid.caption1NumLines = "1"
        m.posterGrid.numColumns = "7"
        m.posterGrid.numRows = "3"
        m.posterGrid.ObserveField("itemSelected", "OnPosterSelected")
        m.posterGrid.ObserveField("itemFocused", "OnPosterFocused")

        m.gridPanel.appendChild(m.PosterGrid)
        m.gridPanel.grid = m.posterGrid
        m.listPanel.nextPanel = m.gridPanel
    end if

    cn = CreateObject("roSGNode", "ContentNode")
    for each item in m.metadata
        n = CreateObject("roSGNode", "ContentNode")
        n.HDPosterUrl = item.HDPosterUrl
        n.SDPosterUrl = item.SDPosterUrl
        n.ShortDescriptionLine1 = item.ShortDescriptionLine1
        cn.appendChild(n)
    end for
    m.posterGrid.content = cn
end sub

sub OnPosterSelected()
    print "MainScene->OnPosterSelected()"
    print m.posterGrid.itemSelected
    StartVideoPlayer(m.posterGrid.itemSelected)
end sub

sub StartVideoPlayer(index as integer)
    print "MainScene->StartVideoPlayer()"
    print m.metadata[index].ShortDescriptionLine1
    m.video.content = m.metadata[index]

    ' Get the previous playback position, if any, and start playing
    GetKeystoreValue(m.video.content.Title, "StartPlayback")
end sub


' Called by GetKeystoreValue
sub StartPlayback()
    print "MainScene->StartPlayback()"
    ResetKeystoreTask()

    ' Was there a result?
    if m.keystoreTask.value <> ""
        m.video.seek = m.keystoreTask.value.ToInt()
    end if
    ' Play the selected video
    m.video.visible = true
    m.video.SetFocus(true)
    m.video.control = "play"
end sub

sub OnPosterFocused()
    print "MainScene->OnPosterFocused()"
    print m.posterGrid.itemFocused
    print m.metadata[m.posterGrid.itemFocused].ShortDescriptionLine1
    m.details.text = m.categories[m.listPanel.createNextPanelIndex] + " | " + m.metadata[m.posterGrid.itemFocused].ShortDescriptionLine1
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
    print "server url = "; m.validateTask.serverurl
    print "valid? "; m.validateTask.valid
    print "keystore? "; m.validateTask.keystore
    if not m.validateTask.valid then
        ' Still invalid, run it again
        RunSetupServerDialog(m.validateTask.serverurl)
    else
        ' Valid url, trigger the content load
        m.top.serverurl = m.validateTask.serverurl
        ' And save it for next time
        RegWrite("ServerURL", m.validateTask.serverurl)
        m.keystoreTask.has_keystore = m.validateTask.keystore
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

sub SetupVideoPlayer()
    ' Setup the video player
    m.video = m.top.FindNode("player")
    m.video.observeField("state", "OnVideoStateChange")
    m.video.observeField("position", "OnVideoPositionChange")
    m.video.notificationInterval = 5
    ' map of events that should be handled on state change
    m.statesToHandle = {
        finished: ""
        error:    ""
    }
end sub

sub OnVideoStateChange()
    print "MainScene->OnVideoStateChange()"
    ? "video state: " + m.video.state
    if m.video.state = "finished"
        ' Set the playback position back to 0 if it played all the way
        SetKeystoreValue(m.video.content.Title, "0", "ResetKeystoreTask")
    end if
    if m.video.content <> invalid AND m.statesToHandle[m.video.state] <> invalid
        m.timer = CreateObject("roSgnode", "Timer")
        m.timer.observeField("fire", "CloseVideoPlayer")
        m.timer.duration = 0.3
        m.timer.control = "start"
    end if
end sub

sub CloseVideoPlayer()
    print "MainScene->CloseVideoPlayer()"
    m.video.visible = false
    m.video.control = "stop"
    m.posterGrid.SetFocus(true)
end sub

sub OnVideoPositionChange()
    print "MainScene->OnVideoPositionChange()"
    if m.video.positionInfo = invalid
        return
    end if
    print "position = "; m.video.positionInfo.video
    SetKeystoreValue(m.video.content.Title, m.video.positionInfo.video.ToStr(), "ResetKeystoreTask")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press
        if key = "back"  'If the back button is pressed
            if m.video.visible
                CloseVideoPlayer()
                return true
            else
                return false
            end if
        else if key = "play"
            StartVideoPlayer(m.posterGrid.itemFocused)
        end if
    end if
end Function
