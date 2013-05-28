'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2013 Brian C. Lane All Rights Reserved.
'********************************************************************

'********************************************************************
'** Display search string
'********************************************************************
Function searchScreen(screenItems As Object) As Object
' screenItems is the double roArray of the screen objects. First row is the
' search row, so ignore it.

    port = CreateObject("roMessagePort")
    screen = CreateObject("roSearchScreen")
    screen.SetMessagePort(port)
    screen.SetSearchTermHeaderText("Suggestions:")
    screen.SetSearchButtonText("search")
    screen.SetClearButtonEnabled(false)

    screen.Show()

    suggestions = invalid
    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roSearchScreenEvent" then
            if msg.isScreenClosed()
                return invalid
            else if msg.isPartialResult() then
                print "partial search: "; msg.GetMessage()
                suggestions = getSuggestions(screenItems, msg.GetMessage())
                terms = getTitles(suggestions)
                screen.SetSearchTerms(terms)
            else if msg.isFullResult()
                print "full search: "; msg.GetMessage()
                return suggestions
            else
                print "Unknown event: "; msg.GetType(); " msg: ";sg.GetMessage()
            end if
        end if
    end while
End Function

'********************************************************************
'** Return an array of suggested movies objects
'********************************************************************
Function getSuggestions(items As Object, needle As String) As Object
    suggestions = CreateObject("roArray", 10, true)
    ' iterate the whole list, gathering matches on Title
    For i = 1 to items.Count()-1
        For Each movie In items[i]
            if Instr(1, LCase(movie.Title), needle) <> 0 then
                suggestions.Push(movie)
            end if
        End For
    End For
    Sort(suggestions, function(k)
                        return LCase(k.Title)
                      end function)
    return suggestions
End Function

'********************************************************************
'** Return an array of titles
'********************************************************************
Function getTitles(movies As Object) As Object
    titles = CreateObject("roArray", 10, true)
    For Each movie In movies
        titles.Push(movie.Title)
    End For
    return titles
End Function

