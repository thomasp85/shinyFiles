library(shiny)
library(shinyFiles)

shinyServer(function(input, output) {
    output$file <- shinyFileChoose(input, 'file', root=R.home(), restrictions=system.file(package='base'))
    output$filepaths <- renderPrint({parseFilePaths(R.home(), input$file)})
})