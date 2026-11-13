# shinyFiles (development version)

* `parseFilePaths()` and `parseSavePath()` no longer return an extra
  `stringsAsFactors` column. `tibble()` treats that argument as data, so every
  result has had a stray logical column since 2017.
* An invalid `pattern` regular expression is still ignored, but no longer
  logs a warning every time a folder is listed.
* **Behaviour change:** `restrictions` now matches whole folders. Restricting
  `/data` hides `/data` and everything inside it, but no longer also hides
  `/data2`, `/database` or any other path that merely contains the text.
  Restrictions should be absolute paths; a bare name such as `"secret"` no
  longer hides every path containing it.
* `shinyDirChoose()` accepts `pattern`, which filters the files shown beside the
  folder tree. It used to fail with "unused argument" as soon as the dialog
  opened.
* `shinySaveButton(filetype = NULL)` (or an empty list) no longer stops the
  save dialog from opening; it behaves like leaving `filetype` out.
* Pressing Esc in the path box ("pencil") closes the path box instead of the
  whole dialog, as it already did for the new-folder box.

# shinyFiles 0.9.4

This release passes maintenance of the package to Michael Bell
(<bell_michael_a@lilly.com>), with Thomas Lin Pedersen remaining as an author.
Thomas has agreed to the change. The release also ships accumulated work
(see below) since the 0.9.3 CRAN release.

* Fixed #185 (@pietrodita)
* Accepted pull request from @lanceupton to address #181
* Typed paths in the path box ("pencil") are now resolved against the
  configured roots on the server, so an absolute path is navigated to rather
  than appended under the currently selected volume. Previously an absolute
  path only worked when its root happened to already be selected, and otherwise
  reported "Folder does not exist". Paths outside every root do not navigate.
* Added a loading overlay while a directory listing is in flight, so slow
  listings on networked filesystems no longer look like a hang.
* `shinyFileSave()` now defers building its `fileGetter`/`dirCreator` until a
  request comes in, matching `shinyFileChoose()`, so `...` arguments (e.g.
  `filetypes`) may be reactive expressions (shinyFiles/shinyFiles#196,
  #195, @WilDoane).
* Fixed the keydown (Enter/Escape) and backdrop-click handlers losing track
  of which modal is on top when more than one shinyFiles dialog is open at
  once, so keyboard shortcuts and backdrop dismissal could act on the wrong
  dialog (shinyFiles/shinyFiles#201, @Tazovsky).
* The volume dropdown now has a "Recent" group listing folders where a
  selection or save was recently confirmed, so a user can jump straight back to
  them. The list is kept in the browser's local storage (per user and browser,
  shared by every shinyFiles button on the page), and only folders inside the
  current dialog's roots are shown. Control the length with the new `recent`
  argument to `shinyFileChoose()`, `shinyDirChoose()` and `shinyFileSave()`
  (default 10, `0` to disable).
* The folder chooser is much faster on network filesystems. Building the tree
  no longer lists the inside of every collapsed folder just to decide whether
  to draw an expand arrow (a folder with no subfolders now loses its arrow
  when opened), and both the tree and the file listing tell folders from files
  by the entry type the listing already returned, instead of a separate lookup
  for each entry. On a home folder with 490 entries, opening the folder
  chooser went from about 8,300 filesystem lookups to under 600.
* Clicks inside an open folder chooser no longer re-read every expanded
  folder. Listings are kept for as long as the dialog is open, so a click only
  reads the folder it touches. They are re-read when the dialog is reopened,
  on refresh, on each `updateFreq` tick, and after creating a folder, so
  changes made outside the dialog show up at those points rather than on
  every click.
* After the folder chooser draws its tree, the server checks the collapsed
  folders in the background and the expand arrows disappear from those with no
  subfolders, without the user having to click them. The check runs in short
  slices between requests, so it doesn't hold up the dialog or later clicks,
  and it stops when a newer response or the end of the session replaces it.
  This adds `later` to Imports.

# shinyFiles 0.9.3

* Standard upkeep

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
