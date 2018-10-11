shinyFiles 0.7.2
--------------------------------------------------------------------

* Sort files and folders by modification date or creation date in dir chooser (@AFriendlyRobot [PR105](https://github.com/thomasp85/shinyFiles/pull/105))
* Fix for softlinks / shortcuts used with `shinyDirChoose` by @raggaraluz [PR104](https://github.com/thomasp85/shinyFiles/pull/104) 
* Resizing modal (@Unfriendly [PR100](https://github.com/thomasp85/shinyFiles/pull/100))

UI improvement listed below by @AFriendlyRobot [PR97](https://github.com/thomasp85/shinyFiles/pull/97)

* Close modal with escape key or by clicking outside the modal, i.e., the equivalent of easyClose for Shiny modals (#76)
* Open a folder with the enter key (#63)
* Double click file to select and close modal (#74)
* Navigate file and folder selection with arrow keys
* Select with the Enter, i.e., a shortcut to click the select button. Enter should open a folder but select a file + close modal
* Save on Enter in textinput for file save modal (i.e., equivalent of clicking the select button)
* A refresh button to update the list of files and directories shown
* Refresh the file and folder information when a shinyFiles button is clicked

shinyFiles 0.7.1
--------------------------------------------------------------------

* Close modal on ESC (@vnijs)
* Force file selection on double click (@AFriendlyRobot [PR95](https://github.com/thomasp85/shinyFiles/pull/95))
* `shinyFiles` now uses the [fs](https://github.com/r-lib/fs) package and works with Chinese, Russian, etc. characters (@vnijs [PR92](https://github.com/thomasp85/shinyFiles/pull/92))
* Use select file type icons from Rstudio with permission (@vnijs [PR86](https://github.com/thomasp85/shinyFiles/pull/86))
