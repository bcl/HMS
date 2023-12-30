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

    ' Get the server URL from the registry or a user dialog
    url = RegRead("ServerURL")
    if url = invalid then
        RunSetupServerDialog("")
    else
        ' Validate the url
        RunValidateURLTask(url)
    end if

    ' Setup the video player node
    SetupVideoPlayer()
end sub


'****************
' Clock functions
'****************

' StartClock starts displaying the clock in the upper right of the screen
' It calls UpdateClock every 5 seconds
sub StartClock()
    m.clock = m.top.FindNode("clock")
    m.clockTimer = m.top.FindNode("clockTimer")
    m.clockTimer.ObserveField("fire", "UpdateClock")
    m.clockTimer.control = "start"
    UpdateClock()
end sub

' Update the clock, showing HH:MM AM/PM in the upper right of the screen
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


'******************
' Content functions
'******************
'
' RunContentTask is called when the server url has been set from the registry or
' entered by the user, and verified to be valid.
' It then starts the task to load the list of categories
sub RunContentTask()
    print "MainScene->RunContentTask()"

    m.contentTask = CreateObject("roSGNode", "MainLoaderTask")
    m.contentTask.serverurl = m.top.serverurl
    m.contentTask.ObserveField("categories", "OnCategoriesLoaded")
    m.contentTask.control = "run"
end sub

' OnCategoriesLoaded is called when the list of categories has been recalled
' from the server. It is returned as a list of strings and is displayed on
' the left side of the screen.
sub OnCategoriesLoaded()
    print "MainScene->OnCategoriesLoaded()"
    print m.contentTask.categories
    m.categories = m.contentTask.categories

    ' Add these to the list on the left side of the screen
    m.panels = m.top.FindNode("panels")
    m.listPanel = m.panels.CreateChild("ListPanel")
    m.listPanel.observeField("createNextPanelIndex", "OnCreateNextPanelIndex")

    m.labelList = CreateObject("roSGNode", "LabelList")
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

' OnCreateNextPanelIndex is called when a new category is selected (up/down)
' It populates the poster grid on the right of the screen
sub OnCreateNextPanelIndex()
    print "MainScene->OnCreateNextPanelIndex()"
    print m.listPanel.createNextPanelIndex
    print m.categories[m.listPanel.createNextPanelIndex]
    m.details.text = ""
    RunCategoryLoadTask(m.categories[m.listPanel.createNextPanelIndex])
end sub

' RunCategoryLoadTask runs a task to get the metadata for the selected category
' It calls OnMetadataLoaded when it is done
sub RunCategoryLoadTask(category as string)
    print "MainScene->RunCategoryLoadTask()"
    print category

    m.metadataTask = CreateObject("roSGNode", "CategoryLoaderTask")
    m.metadataTask.serverurl = m.top.serverurl
    m.metadataTask.category = category
    m.metadataTask.ObserveField("metadata", "OnMetadataLoaded")
    m.metadataTask.control = "run"
end sub

' OnMetadataLoaded is called when it has retrieved the metadata for the category
' It creates one GridPanel and one PosterGrid then re-populates them with each
' new batch of metadata.
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

    ' Try to get the last selected poster for this category
    GetKeystoreValue(m.metadataTask.category, "JumpToPoster")
end sub

' OnPosterSelected it called when OK is hit on the selected poster
' It starts the video player
sub OnPosterSelected()
    print "MainScene->OnPosterSelected()"
    print m.posterGrid.itemSelected
    StartVideoPlayer(m.posterGrid.itemSelected)

    ' Store the new selection for this category
    SetKeystoreValue(m.metadataTask.category, m.posterGrid.itemSelected.ToStr(), "ResetKeystoreTask")
end sub

' OnPosterFocused updates the information at the top of the screen with the
' category name and the name of the selected video
sub OnPosterFocused()
    print "MainScene->OnPosterFocused()"
    print m.posterGrid.itemFocused
    print m.metadata[m.posterGrid.itemFocused].ShortDescriptionLine1
    m.details.text = m.categories[m.listPanel.createNextPanelIndex] + " | " + m.metadata[m.posterGrid.itemFocused].ShortDescriptionLine1
end sub


' JumpToPoster moves the selection to the last played video if there is one
sub JumpToPoster()
    ResetKeystoreTask()

    ' Was there a result?
    if m.keystoreTask.value <> ""
        item =  m.keystoreTask.value.ToInt()
        if item < m.metadata.Count()
            ' If the animation will be short, animate, otherwise jump
            if item < 42
                m.posterGrid.animateToItem = item
            else
                m.posterGrid.jumpToItem = item
            end if
        end if
    end if
end sub

'***********************
' Video player functions
'***********************

' SetupVideoPlayer sets up the observers for the video node
' and how often it will report the playback position
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

' StartVideoPlayer is called with the index of the video to play
' It runs a keystore task to retrieve the last playback position for the
' selected video and then calls StartPlayback
sub StartVideoPlayer(index as integer)
    print "MainScene->StartVideoPlayer()"
    print m.metadata[index].ShortDescriptionLine1
    m.video.content = m.metadata[index]

    ' Get the previous playback position, if any, and start playing
    GetKeystoreValue(m.video.content.Title, "StartPlayback")
end sub

' StartPlayback is called by GetKeystoreValue which may have a starting
' position. If so, it is set, and playback is started.
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

' OnVideoStateChanged is called when the playback is finished or there is an error
' it will save the last playback position and close the video player
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

' CloseVideoPlayer coses the player and stops playback, returning focus to the
' poster grid.
sub CloseVideoPlayer()
    print "MainScene->CloseVideoPlayer()"
    m.video.visible = false
    m.video.control = "stop"
    m.posterGrid.SetFocus(true)
end sub

' OnVideoPositionChange is called every 5 seconds and it sends the position
' to the keystore server
sub OnVideoPositionChange()
    print "MainScene->OnVideoPositionChange()"
    if m.video.positionInfo = invalid
        return
    end if
    print "position = "; m.video.positionInfo.video
    SetKeystoreValue(m.video.content.Title, m.video.positionInfo.video.ToStr(), "ResetKeystoreTask")
end sub

' onKeyEvent handles hitting 'back' during playback and play when selecting a poster grid
' which normally doesn't start playback.
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


'***********************
' Server setup functions
'***********************

' RunSetupServerDialog runs the dialog prompting the user for the server url
sub RunSetupServerDialog(url as string)
    print "MainScene->RunSetupServerDialog()"
    m.serverDialog = createObject("roSGNode", "SetupServerDialog")
    m.serverDialog.ObserveField("serverurl", "OnSetupServerURL")
    m.serverDialog.text = url
    m.top.dialog = m.serverDialog
end sub

' OnSetupServerURL is called when the user has entered a url, it then validates it
' by calling RunValidateURLTask
sub OnSetupServerURL()
    print "MainScene->OnSetupServerURL()"
    print m.serverDialog.serverurl

    RunValidateURLTask(m.serverDialog.serverurl)
end sub

' RunValidateURLTask is called to validate the url that the user entered in the dialog
' it starts a task and calls OnValidateChanged when done.
sub RunValidateURLTask(url as string)
    print "MainScene->RunValidateURLTask()"

    m.validateTask = CreateObject("roSGNode", "ValidateURLTask")
    m.validateTask.serverurl = url
    m.validateTask.ObserveField("valid", "OnValidateChanged")
    m.validateTask.control = "run"
end sub

' OnValidateChanged checks the result of validating the URL and either runs the setup
' dialog again, or sets the serverurl which triggers loading the categories and the
' rest of the screen.
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


' ******************
' Keystore functions
' ******************

' GetKeystoreValue retrieves a string from the keystore server
' It calls the callback when it is done (or has failed)
' The callback needs to call ResetKeystoreTask to clear the
' done field.
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

' SetKeystoreValue sets a key to a string on the keystore server
' It calls the callback when it is done (or has failed)
' The callback needs to call ResetKeystoreTask to clear the
' done field.
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

' ResetKeystoreTask clears the observer and sets done back to false
sub ResetKeystoreTask()
    m.keystoreTask.UNObserveField("done")
    m.keystoreTask.done = false
end sub
