function init()
    print "SetupServerDialog->Init()"

'    m.top.width = 1800
    m.top.title   = "Setup HMS Server URL"
    m.top.message = ["Enter server name or IP address"]
    m.top.buttons = ["OK"]

    m.top.observeFieldScoped("buttonSelected", "dismissDialog")
    m.top.observeFieldScoped("text", "textChanged")

    m.top.observeFieldScoped("wasClosed", "wasClosedChanged")
end function

sub wasClosedChanged()
    print "Example StandardKeyboardDialog Closed"
    print "FINAL TEXT: "; m.top.text
    m.top.serverurl = m.top.text
end sub

sub textChanged()
    print "ENTERED TEXT: "; m.top.text
end sub

sub dismissDialog()
    m.top.close = true
end sub
