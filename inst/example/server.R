library(shiny)
library(shinyFiles)
library(fs)

shinyServer(function(input, output, session) {
  volumes <- c(Home = fs::path_home(), "R Installation" = R.home(), getVolumes()())
  shinyFileChoose(input, "file", roots = volumes, session = session)
  shinyDirChoose(input, "directory", roots = volumes, session = session, restrictions = system.file(package = "base"))
  shinyFileSave(input, "save", roots = volumes, session = session, restrictions = system.file(package = "base"))
  
  ## print to console to see how the value of the shinyFiles 
  ## button changes after clicking and selection
  observe({
    cat("\ninput$file value:\n\n")
    print(input$file)
  })
  
  observe({
    cat("\ninput$directory value:\n\n")
    print(input$directory)
  })
  
  observe({
    cat("\ninput$save value:\n\n")
    print(input$save)
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
