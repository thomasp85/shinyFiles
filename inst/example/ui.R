library(shiny)
library(shinyFiles)

shinyUI(pageWithSidebar(
    headerPanel(
        'File selections with shinyFiles',
        'shinyFiles example'
        ),
    sidebarPanel(
        tags$h4('A shinyFiles button'),
        tags$p('The button is set to expose the users R installation directory. 
               Only one file can be selected and the base package location has
               been hidden.'),
        tags$p('Notice that, as the file selection box gets summoned multiple
               times, the browsing history and view type are remembered. This
               functionality is not shared between multiple instances of
               shinyFiles buttons.'),
        shinyFilesButton('file', 'File select', 'Please select a file', FALSE)
        ),
    mainPanel(
        tags$h4('The output of a file choice'),
        tags$p('When one or several files are chosen the result is made 
               available to the shinyServer instance. In order for it to get the
               formatting expected of a filepath it must first be fed into
               parseFilePaths after which the output matches the formatting of
               that returned by shinys own fileInput widget.'),
        verbatimTextOutput('filepaths')
        )
))
