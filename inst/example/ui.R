library(shiny)
library(shinyFiles)

shinyUI(pageWithSidebar(
    headerPanel(
        'Selections with shinyFiles',
        'shinyFiles example'
        ),
    sidebarPanel(
        img(src='logo.png', style="float: left; width: 120px; margin-right: 10px; margin-top: 5px"),
        tags$p('The following buttons will expose the users R installation
               directory. To showcase the restriction feature the base package
               has been hidden.'),
        tags$p('As each button is used multiple times, the last location is
               remembered, as well as any other states. Each button has its own
               memory.'),
        tags$hr(),
        shinyFilesButton('file', 'File select', 'Please select a file', FALSE),
        tags$p(),
        tags$p('The file selection button allows the user to select one or
               several files and get their absolute position communicated back
               to the shiny server. In this example the button has been set to
               single-file mode.'),
        tags$hr(),
        shinyDirButton('directory', 'Folder select', 'Please select a folder'),
        tags$p(),
        tags$p('This button lets the user navigate the file system and select a
               folder. The absolute path of the selected folder is then send
               back to the server. While only folders can be selected, it is
               possible to get an overview of the content beforehand. 
               Furthermore it is permission aware and warns if a folder with 
               missing write permissions is selected. Lastly it is possible to
               create folders on the fly'),
        tags$hr(),
        shinySaveButton('save', 'Save file', 'Save file as...', filetype=list(text='txt', picture=c('jpeg', 'jpg'))),
        tags$p(),
        tags$p('The last type of button is the save button which allows the user
               to navigate to a position in the filesystem and specify the name
               of a new file to be send back to the server. As above write 
               permissions are communicated and folders can be created. It is
               possible to specify a range of different filetypes that the user
               can choose between. In this example it is "text" and "picture"')
        ),
    mainPanel(
        tags$h4('The output of a file selection'),
        tags$p(HTML('When one or several files are chosen the result is made 
               available to the shinyServer instance. In order for it to get the
               formatting expected of a filepath it must first be fed into
               <code>parseFilePaths()</code> after which the output matches the formatting of
               that returned by shinys own fileInput widget.')),
        verbatimTextOutput('filepaths'),
        tags$hr(),
        tags$h4('The output of a folder selection'),
        tags$p(HTML('When a folder is selected the position of the folder is sent to 
               the server and can be formatted with <code>parseDirPath()</code> to reflect a
               standard path string as returned by e.g. <code>choose.dir()</code> on windows
               systems.')),
        verbatimTextOutput('directorypath'),
        tags$hr(),
        tags$h4('The output of a file save'),
        tags$p(HTML('When a file is "saved" the name, path and type is sent back to
               the server, where it can be formatted with <code>parseSavePath()</code>. The 
               format after parsing is very similar to a file choise, except
               size information is omitted (often the file doesn\'t exist yet)
               and type is now available (provided that filetype information has
               been send from the server).')),
        verbatimTextOutput('savefile')
        )
))
