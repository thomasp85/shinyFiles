library(shiny)
library(shinyFiles)

shinyServer(function(input, output, session) {
  volumes <- c(Home = fs::path_home(), "R Installation" = R.home(), getVolumes()())
  shinyFileChoose(input, "file", roots = volumes, session = session)
  shinyDirChoose(input, "directory", roots = volumes, session = session, restrictions = system.file(package = "base"))
  shinyFileSave(input, "save", roots = volumes, session = session, restrictions = system.file(package = "base"))
  
  ## print to console
  observe({
    print(parseFilePaths(volumes, input$file))
  })
  observe({
    print(parseFilePaths(volumes, input$file))
  })
  observe({
    print(parseSavePath(volumes, input$save))
  })
  
  ## print to browser
  output$filepaths <- renderPrint({
    parseFilePaths(volumes, input$file)
  })
  output$directorypath <- renderPrint({
    parseDirPath(volumes, input$directory)
  })
  output$savefile <- renderPrint({
    parseSavePath(volumes, input$save)
  })
})
