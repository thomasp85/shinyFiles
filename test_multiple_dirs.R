library(shiny)
library(shinyFiles)
library(fs)

ui <- fluidPage(
  titlePanel("Test Multiple Directory Choosers"),
  sidebarLayout(
    sidebarPanel(
      h4("Multiple Directory Choosers"),
      p("This test app has multiple directory choosers to verify that modals close correctly."),
      hr(),
      shinyDirButton("dir1", "Directory 1", "Please select first directory"),
      br(), br(),
      shinyDirButton("dir2", "Directory 2", "Please select second directory"),
      br(), br(),
      shinyDirButton("dir3", "Directory 3", "Please select third directory"),
      hr(),
      p("Try opening multiple directory choosers and clicking 'Select' - the modal should close properly.")
    ),
    mainPanel(
      h4("Selected Directories:"),
      verbatimTextOutput("dir1_output"),
      verbatimTextOutput("dir2_output"),
      verbatimTextOutput("dir3_output")
    )
  )
)

server <- function(input, output, session) {
  volumes <- c(Home = fs::path_home(), "R Installation" = R.home(), getVolumes()())
  
  # Set up multiple directory choosers
  shinyDirChoose(input, "dir1", roots = volumes, session = session)
  shinyDirChoose(input, "dir2", roots = volumes, session = session)
  shinyDirChoose(input, "dir3", roots = volumes, session = session)
  
  # Output the selected directories
  output$dir1_output <- renderPrint({
    if (is.integer(input$dir1)) {
      cat("Directory 1: No directory selected")
    } else {
      cat("Directory 1:", parseDirPath(volumes, input$dir1))
    }
  })
  
  output$dir2_output <- renderPrint({
    if (is.integer(input$dir2)) {
      cat("Directory 2: No directory selected")
    } else {
      cat("Directory 2:", parseDirPath(volumes, input$dir2))
    }
  })
  
  output$dir3_output <- renderPrint({
    if (is.integer(input$dir3)) {
      cat("Directory 3: No directory selected")
    } else {
      cat("Directory 3:", parseDirPath(volumes, input$dir3))
    }
  })
}

shinyApp(ui = ui, server = server)
