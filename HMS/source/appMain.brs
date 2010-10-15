'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2010 Brian C. Lane All Rights Reserved.
'********************************************************************

Sub Main()

    m.port = CreateObject("roMessagePort")

    'initialize theme attributes like titles, logos and overhang color
    initTheme()

    if not checkServerUrl(false) then
        ' Need to show an error to the user here and exit when they click done
        print "Server URL is invalid"
        return
    endif

    displayDirectory("http://"+RegRead("ServerURL") )
End Sub


'*************************************************************
'** Set the configurable theme attributes for the application
'** 
'** Configure the custom overhang and Logo attributes
'** Theme attributes affect the branding of the application
'** and are artwork, colors and offsets specific to the app
'*************************************************************

Sub initTheme()

    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")

    theme.OverhangOffsetSD_X = "72"
    theme.OverhangOffsetSD_Y = "31"
    theme.OverhangSliceSD = "pkg:/images/Overhang_Background_SD.png"
    theme.OverhangLogoSD  = "pkg:/images/Overhang_Logo_SD.png"

    theme.OverhangOffsetHD_X = "125"
    theme.OverhangOffsetHD_Y = "35"
    theme.OverhangSliceHD = "pkg:/images/Overhang_Background_HD.png"
    theme.OverhangLogoHD  = "pkg:/images/Overhang_Logo_HD.png"

    app.SetTheme(theme)

End Sub

