# shinyFiles 0.7.5

* Check if "wmic" is accessible on Windows. If not, return a message to the user 
  and a volumes vector with only the HOMEDRIVE
* Updated example in "showcase" mode. Also, demonstrates the use of `as.integer` 
  to check if a file or directory has been selected

# shinyFiles 0.7.4

* Use `inherits` rather than `class(...) == ...` (#123) 

# shinyFiles 0.7.3

* Check parent existence when attempting to navigate 'down' in directory 
  selection to avoid down-arrow freeze (@AFriendlyRobot, #118)
* Return the epoch in milliseconds from the server (@keqiang, #113)
* Allow launching shinyFiles from within a shiny modal (@ifellows, #111)

# shinyFiles 0.7.2

* Sort files and folders by modification date or creation date in dir chooser 
  (@AFriendlyRobot, #105)
* Fix for softlinks / shortcuts used with `shinyDirChoose` (@raggaraluz, #104)
* Resizing modal (@Unfriendly, #100)
* UI improvement listed below by @AFriendlyRobot, #97
  - Close modal with escape key or by clicking outside the modal, i.e., the 
    equivalent of easyClose for Shiny modals (#76)
  - Open a folder with the enter key (#63)
  - Double click file to select and close modal (#74)
  - Navigate file and folder selection with arrow keys
  - Select with the Enter, i.e., a shortcut to click the select button. Enter 
    should open a folder but select a file + close modal
  - Save on Enter in textinput for file save modal (i.e., equivalent of clicking the select button)
  - A refresh button to update the list of files and directories shown
  - Refresh the file and folder information when a shinyFiles button is clicked

# shinyFiles 0.7.1

* Close modal on ESC (@vnijs)
* Force file selection on double click (@AFriendlyRobot, #95)
* `shinyFiles` now uses the [fs](https://github.com/r-lib/fs) package and works 
  with Chinese, Russian, etc. characters (@vnijs, #92)
* Use select file type icons from Rstudio with permission (@vnijs, #86)
