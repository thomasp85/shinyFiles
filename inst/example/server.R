library(shiny)
library(shinyFiles)

shinyServer(function(input, output, session) {
    shinyFileChoose(input, 'file', roots=getVolumes(), session=session, restrictions=system.file(package='base'))
    output$filepaths <- renderPrint({parseFilePaths(getVolumes()(), input$file)})
})
