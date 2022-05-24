# shinyFiles 0.9.2

* Fixes for logical checks that may see a vector of length > 1 (https://github.com/thomasp85/shinyFiles/issues/159)
* PR from @sgvignali (https://github.com/thomasp85/shinyFiles/pull/164) to have `shinySaveButton` trigger an event that can be detected and used in JS code
* Fix to keep getVolumes working after WMIC.exe is deprecated (https://github.com/thomasp85/shinyFiles/issues/163). Thanks go to @Mailinnia
* Fixes to display modals correctly with BS4 (https://github.com/thomasp85/shinyFiles/issues/158). Thanks go to @ruthkr
* Fix long delay if a network drive is not mountable without VPN (https://github.com/thomasp85/shinyFiles/issues/155)

# shinyFiles 0.9.0

* Security fix that ensures a user cannot bypass folder navigation limits (@lz100 issue #152, @bellma-lilly PR #153)
* Allow additional arguments to be passed to shinyFiles buttons and links (e.g., onclick)
* Fix for creating a new folder using the `Create new folder > +` button in shinyFileSave (https://github.com/thomasp85/shinyFiles/issues/142)
* Allow directory chooser to disable creating new directories (@dipterix #144). Extended to allow the same functionality when saving files

# shinyFiles 0.8.0

* Increase in default height based on a experimentation by @SamGG. This works well 
  with the new default detail view. Users can still adjust in CSS as discussed in 
  https://github.com/thomasp85/shinyFiles/issues/134
* The default `viewtype` in the file browser has been changed to "detail". A new 
  argument `viewtype` has been added to shinyFilesButton, shinyFilesLink, shinySaveButton, 
  and shinySaveLink that should be one of "detail" (default), "list", or "icon"
* The default size of the modal has been set to `modal-lg` to provide a bit more room for 
  file information in the "detail" view. This will, however, automatically adjust to 
  smaller screens as needed
* Allow the user to type a path, including the filename. In filechoose, the file will be 
  selected if it exists. In filesave, if the file does not exist, but the base directory 
  does, the filename will be entered into the dialog. (@bellma-lilly, #129 and #131)

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
