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

    m.top.valid = isURLValid(m.top.serverurl)
    if m.top.valid then
        print "Is VALID"
    else
        print "Is NOT VALID"
    end if
end sub
