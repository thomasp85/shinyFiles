library(shiny)
library(shinyFiles)

shinyServer(function(input, output) {
    output$file <- shinyFileChoose(input, 'file', roots=getVolumes(), restrictions=system.file(package='base'))
    output$filepaths <- renderPrint({parseFilePaths(getVolumes()(), input$file)})
})
