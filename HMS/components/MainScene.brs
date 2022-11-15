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
    print m.categories[m.listPanel.createNextPanelIndex]
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
    print "Got "; m.metadataTask.metadata.Count(); " items."
    m.metadata = m.metadataTask.metadata

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
        m.posterGrid.ObserveField("itemSelected", "OnPostedSelected")
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
    print "MainScene->OnPosterGridSelected()"
    print m.posterGrid.itemSelected
    print m.metadata[m.posterGrid.itemSelected].ShortDescriptionLine1
end sub

sub OnPosterFocused()
    print "MainScene->OnPosterGridSelected()"
    print m.posterGrid.itemFocused
    print m.metadata[m.posterGrid.itemFocused].ShortDescriptionLine1
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
