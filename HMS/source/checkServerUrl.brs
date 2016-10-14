'*****************************************************************
'**  Home Media Server Application
'**  Copyright (c) 2010-2013 Brian C. Lane All Rights Reserved.
'*****************************************************************

'************************************************************
' ** Check the registry for the server URL
' ** Prompt the user to enter the URL or IP if it is not
' ** found and write it to the registry.
'************************************************************
Function checkServerUrl(forceEdit As Boolean) As Boolean
    serverUrl = RegRead("ServerURL")
    if (serverUrl = invalid) then
        print "ServerUrl not found in the registry"
        serverUrl = "video.local"
    else if not forceEdit and isUrlValid(serverUrl+"/Setup-SD.png") then
        print "Server set to "; serverUrl
        return true
    end if

    screen = CreateObject("roKeyboardScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    screen.SetTitle("HMS Video Server URL")
    screen.SetText(serverURL)
    screen.SetDisplayText("Enter Host Name or IP Address")
    screen.SetMaxLength(25)
    screen.AddButton(1, "finished")
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        print "message received"
        if type(msg) = "roKeyboardScreenEvent"
            if msg.isScreenClosed()
                return false
            else if msg.isButtonPressed() then
                print "Evt: ";msg.GetMessage();" idx:"; msg.GetIndex()
                if msg.GetIndex() = 1 then
                    serverText = screen.GetText()
                    print "Server set to "; serverText

                    if isUrlValid(serverText) then
                        RegWrite("ServerURL", serverText)
                        return true
                    end if
                endif
            endif
        endif
    end while
End Function

'************************************************************
'** Check a URL to see if it is valid
'************************************************************
Function isUrlValid( url As String ) As Boolean
    result = getHTMLWithTimeout(url, 60)
    return not result.error
End Function

