'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Main()
    ShowChannelRSGScreen()
end sub

sub ShowChannelRSGScreen()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.SetMessagePort(m.port)
    scene = screen.CreateScene("MainScene")
    screen.Show()

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.IsScreenClosed() then return
        end if
    end while
end sub
