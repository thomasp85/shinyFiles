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
               shinyFiles buttons.')
        shinyFilesButton('file', 'File select', 'Please select a file', FALSE)
        ),
    mainPanel(
        verbatimTextOutput('filepaths')
        )
))