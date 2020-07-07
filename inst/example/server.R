library(shiny)
library(shinyFiles)
library(fs)

shinyServer(function(input, output, session) {
  volumes <- c(Home = fs::path_home(), "R Installation" = R.home(), getVolumes()())
  shinyFileChoose(input, "file", roots = volumes, session = session)
  # by setting `allowDirCreate = FALSE` a user will not be able to create a new directory
  shinyDirChoose(input, "directory", roots = volumes, session = session, restrictions = system.file(package = "base"), allowDirCreate = FALSE)
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
    if (is.integer(input$file)) {
      cat("No files have been selected (shinyFileChoose)")
    } else {
      parseFilePaths(volumes, input$file)
    }
  })
  
  output$directorypath <- renderPrint({
    if (is.integer(input$directory)) {
      cat("No directory has been selected (shinyDirChoose)")
    } else {
      parseDirPath(volumes, input$directory)
    }
  })
  
  output$savefile <- renderPrint({
    if (is.integer(input$save)) {
      cat("No file-save path has been set (shinyFileSave)")
    } else {
      parseSavePath(volumes, input$save)
    }
  })
})
