'********************************************************************
'**  Home Media Server Application - ValidateURLTask
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "ValidateURLTask->Init()"
    m.top.functionName = "ValidateURL"
end sub

' ValidateURL is executed when  m.validateURLTask.control = "run"
' It checks serverurl and sets valid to true/false
sub ValidateURL()
    print "ValidateURLTask->GetContent()"
    print m.top.serverurl

    valid = isURLValid(m.top.serverurl)
    if valid then
        print "Is VALID"

        ' See if there is a keystore available
        m.top.keystore = isUrlValid(m.top.serverurl+"/keystore/version")
        m.top.valid = valid
    else
        print "Is NOT VALID"
    end if
end sub
