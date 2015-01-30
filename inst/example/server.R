library(shiny)
library(shinyFiles)

shinyServer(function(input, output, session) {
    shinyFileChoose(input, 'file', roots=c('R Installation'=R.home()), session=session, restrictions=system.file(package='base'))
    output$filepaths <- renderPrint({parseFilePaths(c('R Installation'=R.home()), input$file)})
})
