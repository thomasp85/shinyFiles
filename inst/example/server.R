library(shiny)
library(shinyFiles)

shinyServer(function(input, output, session) {
    volumes <- c('R Installation'=R.home())
    shinyFileChoose(input, 'file', roots=volumes, session=session, restrictions=system.file(package='base'))
    shinyDirChoose(input, 'directory', roots=volumes, session=session, restrictions=system.file(package='base'))
    shinyFileSave(input, 'save', roots=volumes, session=session, restrictions=system.file(package='base'))
    output$filepaths <- renderPrint({parseFilePaths(volumes, input$file)})
    output$directorypath <- renderPrint({parseDirPath(volumes, input$directory)})
    output$savefile <- renderPrint({parseSavePath(volumes, input$save)})
})
