'********************************************************************
'**  Home Media Server Application - KeystoreTask
'**  Copyright (c) 2022 Brian C. Lane All Rights Reserved.
'********************************************************************
sub Init()
    print "KeystoreTask->Init()"

    m.top.functionName = "ExecuteCommand"
end sub

' ExecuteCommand is executed when  m.keystoreTask.control = "run" from MainScene
' This needs to be reset along with UNObserveField("done") to prevent accidental re-triggering
sub ExecuteCommand()
    print "KeystoreTask->ExecuteCommand()"
    print "Server url = "; m.top.serverurl
    print "command = "; m.top.command
    print "key = "; m.top.key
    print "value = "; m.top.value

    if not m.top.has_keystore
        m.top.done = true
        return
    end if

    if m.top.command = "get"
        m.top.value = getKeyValue(m.top.serverurl, m.top.key)
        print "new value = "; m.top.value
    else if m.top.command = "set"
        setKeyValue(m.top.serverurl, m.top.key, m.top.value)
    end if

    m.top.done = true
end sub
