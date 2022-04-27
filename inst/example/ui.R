library(shiny)
library(shinyFiles)

if (require(bslib)) {
  theme <- bslib::bs_theme(version = 4)
} else {
  theme <- NULL
}

fluidPage(
  theme = theme, 
  headerPanel(
    "Selections with shinyFiles",
    "shinyFiles example"
  ),
  sidebarLayout(
    sidebarPanel(
      img(src = "logo.png", style = "float: left; width: 120px; margin-right: 10px; margin-top: 5px"),
      tags$p("The following buttons will expose the users home directory,\n
             R installation directory and other available volumes. To showcase\n 
             the restriction feature the base package has been hidden."),
      tags$p("As each button is used multiple times, the last location is\n
             remembered, as well as any other states. Each button has its own\n
             memory."),
      tags$hr(),
      shinyFilesButton("file", "File select", "Please select a file", multiple = TRUE, viewtype = "detail"),
      tags$p(),
      tags$p('The file selection button allows the user to select one or several 
              files and get their absolute position communicated back to the shiny
              server. In this example the button has been set to single-file mode 
              and the default path has been set to the users home directory.'),
      tags$hr(),
      shinyDirButton("directory", "Folder select", "Please select a folder"),
      tags$p(),
      tags$p("This button lets the user navigate the file system and select a\n
             folder. The absolute path of the selected folder is then sent\n
             back to the server. While only folders can be selected, it is\n
             possible to get an overview of the content beforehand. \n
             Furthermore it is permission aware and warns if a folder with \n
             missing write permissions is selected. Lastly it is possible to\n
             create folders on the fly"),
      tags$hr(),
      shinySaveButton("save", "Save file", "Save file as...", filetype = list(text = "txt", picture = c("jpeg", "jpg")), viewtype = "icon"),
      tags$p(),
      tags$p('The last type of button is the save button which allows the user
              to navigate to a position in the filesystem and specify the name
              of a new file to be sent back to the server. As above, write 
              permissions are communicated and folders can be created. It is
              possible to specify a range of different filetypes that the user
              can choose between. In this example it is "text" and "picture"')
    ),
    mainPanel(
      tags$h4("The output of a file selection"),
      tags$p(HTML("When one or several files are chosen the result is made \n
                  available to the shinyServer instance. In order for it to get the\n
                  formatting expected of a filepath it must first be fed into\n
                  <code>parseFilePaths()</code> after which the output matches the formatting of\n
                  that returned by shiny's own fileInput widget.")),
      verbatimTextOutput("filepaths"),
      tags$hr(),
      tags$h4("The output of a folder selection"),
      tags$p(HTML("When a folder is selected the position of the folder is sent to \n
                  the server and can be formatted with <code>parseDirPath()</code> to reflect a\n
                  standard path string as returned by e.g. <code>choose.dir()</code> on windows\n
                  systems.")),
      verbatimTextOutput("directorypath"),
      tags$hr(),
      tags$h4("The output of a file save"),
      tags$p(HTML('When a file is "saved" the name, path, and type are sent back to
                  the server and formatted with <code>parseSavePath()</code>. The 
                  format after parsing is very similar to a file choice, except
                  size information is omitted (often the file doesn\'t exist yet)
                  and type is now available (provided that filetype information has
                  been sent from the server).')),
      verbatimTextOutput("savefile")
    )
  )
)
